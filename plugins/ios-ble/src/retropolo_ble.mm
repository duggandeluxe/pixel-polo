#include "retropolo_ble.h"

#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>

// Must match plugins/android-ble (RetroPoloBle.java).
static NSString *const kService = @"5b0c7e10-9a1d-4c3e-8f21-524f504f4c01";
static NSString *const kTx = @"5b0c7e10-9a1d-4c3e-8f21-524f504f4c02";   // host -> client (notify)
static NSString *const kRx = @"5b0c7e10-9a1d-4c3e-8f21-524f504f4c03";   // client -> host (write)
static const int kHostId = 1;
static const NSUInteger kMaxMessage = 64 * 1024;
static const NSUInteger kMaxQueue = 400;
static const NSTimeInterval kJoinTimeout = 12.0;
static const NSTimeInterval kSameRoomGap = 0.7;

static NSString *to_ns(const String &s) {
	return [NSString stringWithUTF8String:s.utf8().get_data()];
}

static String to_godot(NSString *s) {
	return s ? String::utf8([s UTF8String]) : String();
}

static PackedByteArray to_bytes(NSData *d) {
	PackedByteArray out;
	out.resize((int)d.length);
	if (d.length > 0) {
		memcpy(out.ptrw(), d.bytes, d.length);
	}
	return out;
}

// Splits a packet into fragments of at most `chunk` payload bytes behind a 1-byte header
// (bit 7 set = more fragments follow).
static NSArray<NSData *> *fragment(NSData *data, NSUInteger chunk) {
	chunk = MAX(chunk, (NSUInteger)19);
	NSMutableArray *out = [NSMutableArray array];
	NSUInteger off = 0;
	do {
		NSUInteger n = MIN(chunk, data.length - off);
		NSMutableData *f = [NSMutableData dataWithLength:n + 1];
		((uint8_t *)f.mutableBytes)[0] = (off + n < data.length) ? 0x80 : 0x00;
		if (n > 0) {
			memcpy((uint8_t *)f.mutableBytes + 1, (const uint8_t *)data.bytes + off, n);
		}
		[out addObject:f];
		off += n;
	} while (off < data.length);
	return out;
}

// Joins fragments back into whole packets.
@interface RPReassembler : NSObject
@property(nonatomic, strong) NSMutableData *buf;
- (NSData *)add:(NSData *)frag;
@end

@implementation RPReassembler
- (instancetype)init {
	if ((self = [super init])) {
		_buf = [NSMutableData data];
	}
	return self;
}
- (NSData *)add:(NSData *)frag {
	if (frag.length < 1) {
		return nil;
	}
	[_buf appendBytes:(const uint8_t *)frag.bytes + 1 length:frag.length - 1];
	if (_buf.length > kMaxMessage) {
		_buf = [NSMutableData data];
		return nil;
	}
	if ((((const uint8_t *)frag.bytes)[0] & 0x80) != 0) {
		return nil;
	}
	NSData *whole = [_buf copy];
	_buf = [NSMutableData data];
	return whole;
}
@end

// A joiner, seen from the host.
@interface RPPeer : NSObject
@property(nonatomic) int peerId;
@property(nonatomic, strong) CBCentral *central;
@property(nonatomic, strong) NSMutableArray<NSData *> *queue;
@property(nonatomic, strong) RPReassembler *rx;
@end

@implementation RPPeer
@end

// All the CoreBluetooth work. Delegates run on the main queue, which is Godot's main thread
// on iOS, so signals are emitted straight away.
@interface RPBleCore : NSObject <CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate>
@property(nonatomic, assign) RetroPoloBLE *owner;
// host
@property(nonatomic, strong) CBPeripheralManager *peripheralManager;
@property(nonatomic, strong) CBMutableCharacteristic *txChar;
@property(nonatomic, copy) NSString *roomName;
@property(nonatomic) BOOL hostWanted;
@property(nonatomic) BOOL advertising;
@property(nonatomic) int nextId;
@property(nonatomic, strong) NSMutableDictionary<NSUUID *, RPPeer *> *peersByCentral;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, RPPeer *> *peersById;
// client
@property(nonatomic, strong) CBCentralManager *centralManager;
@property(nonatomic) BOOL scanWanted;
@property(nonatomic) BOOL scanning;
@property(nonatomic, strong) NSMutableDictionary<NSString *, CBPeripheral *> *known;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *lastSeen;
@property(nonatomic, strong) CBPeripheral *hostPeripheral;
@property(nonatomic, strong) CBCharacteristic *hostTx;
@property(nonatomic, strong) CBCharacteristic *hostRx;
@property(nonatomic) BOOL joined;
@property(nonatomic) BOOL writing;
@property(nonatomic, strong) NSMutableArray<NSData *> *clientQueue;
@property(nonatomic, strong) RPReassembler *clientRx;
@property(nonatomic) NSUInteger joinToken;
@end

@implementation RPBleCore

- (instancetype)initWithOwner:(RetroPoloBLE *)owner {
	if ((self = [super init])) {
		_owner = owner;
		_nextId = 2;
		_peersByCentral = [NSMutableDictionary dictionary];
		_peersById = [NSMutableDictionary dictionary];
		_known = [NSMutableDictionary dictionary];
		_lastSeen = [NSMutableDictionary dictionary];
		_clientQueue = [NSMutableArray array];
		_clientRx = [[RPReassembler alloc] init];
	}
	return self;
}

- (void)emit:(const StringName &)name args:(const Vector<Variant> &)args {
	if (!_owner) {
		return;
	}
	Vector<const Variant *> ptrs;
	for (int i = 0; i < args.size(); i++) {
		ptrs.push_back(&args[i]);
	}
	_owner->emit_signalp(name, args.size() > 0 ? ptrs.ptrw() : nullptr, args.size());
}

// ---------------------------------------------------------------- status
- (void)ensureCentral {
	if (!_centralManager) {
		_centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil
															 options:@{ CBCentralManagerOptionShowPowerAlertKey : @NO }];
	}
}

- (NSString *)status {
	CBManagerAuthorization auth = CBManager.authorization;
	if (auth == CBManagerAuthorizationDenied || auth == CBManagerAuthorizationRestricted) {
		return @"no_permission";
	}
	if (auth == CBManagerAuthorizationNotDetermined) {
		return @"no_permission";   // requestAccess() shows the system prompt
	}
	[self ensureCentral];
	switch (_centralManager.state) {
		case CBManagerStatePoweredOn:
			return @"ready";
		case CBManagerStateUnsupported:
			return @"unsupported";
		case CBManagerStateUnauthorized:
			return @"no_permission";
		default:
			return @"off";
	}
}

- (void)requestAccess {
	[self ensureCentral];   // creating the manager asks for permission the first time
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
	[self emit:"status_changed" args:Vector<Variant>({ to_godot([self status]) })];
	if (central.state == CBManagerStatePoweredOn && _scanWanted && !_scanning) {
		[self startScanNow];
	}
	if (central.state != CBManagerStatePoweredOn && (_joined || _hostPeripheral)) {
		BOOL was = _joined;
		[self closeClient];
		[self emit:(was ? "host_lost" : "join_failed") args:Vector<Variant>({ String("Bluetooth turned off") })];
	}
}

// ---------------------------------------------------------------- host
- (void)hostStart:(NSString *)name maxPlayers:(int)maxPlayers {
	[self closeAll];
	_roomName = name ?: @"";
	_nextId = 2;
	_hostWanted = YES;
	if (!_peripheralManager) {
		_peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil options:nil];
	} else if (_peripheralManager.state == CBManagerStatePoweredOn) {
		[self addService];
	}
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
	if (peripheral.state == CBManagerStatePoweredOn) {
		if (_hostWanted && !_txChar) {
			[self addService];
		}
	} else if (_hostWanted) {
		_hostWanted = NO;
		[self stopHosting];
		[self emit:"host_failed" args:Vector<Variant>({ String("Bluetooth is not ready") })];
	}
}

- (void)addService {
	CBUUID *svcId = [CBUUID UUIDWithString:kService];
	_txChar = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kTx]
												 properties:CBCharacteristicPropertyNotify
													  value:nil
												permissions:CBAttributePermissionsReadable];
	CBMutableCharacteristic *rx = [[CBMutableCharacteristic alloc]
			initWithType:[CBUUID UUIDWithString:kRx]
			  properties:CBCharacteristicPropertyWrite | CBCharacteristicPropertyWriteWithoutResponse
				   value:nil
			 permissions:CBAttributePermissionsWriteable];
	CBMutableService *svc = [[CBMutableService alloc] initWithType:svcId primary:YES];
	svc.characteristics = @[ _txChar, rx ];
	[_peripheralManager removeAllServices];
	[_peripheralManager addService:svc];   // advertising starts in didAddService
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
	if (error) {
		_hostWanted = NO;
		[self stopHosting];
		[self emit:"host_failed" args:Vector<Variant>({ String("This phone can't host over Bluetooth. Let a friend host, or use Wi-Fi.") })];
		return;
	}
	NSString *local = [@"RP:" stringByAppendingString:_roomName];
	[_peripheralManager startAdvertising:@{
		CBAdvertisementDataServiceUUIDsKey : @[ [CBUUID UUIDWithString:kService] ],
		CBAdvertisementDataLocalNameKey : local,
	}];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
	if (error) {
		_hostWanted = NO;
		[self stopHosting];
		[self emit:"host_failed" args:Vector<Variant>({ to_godot(error.localizedDescription) })];
		return;
	}
	_advertising = YES;
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
						 central:(CBCentral *)central
	didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
	if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:kTx]] || _peersByCentral[central.identifier]) {
		return;
	}
	// only a phone that subscribes becomes a player (earbuds and watches never do)
	RPPeer *p = [[RPPeer alloc] init];
	p.peerId = _nextId++;
	p.central = central;
	p.queue = [NSMutableArray array];
	p.rx = [[RPReassembler alloc] init];
	_peersByCentral[central.identifier] = p;
	_peersById[@(p.peerId)] = p;
	[self emit:"peer_connected" args:Vector<Variant>({ p.peerId })];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
							 central:(CBCentral *)central
	didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
	RPPeer *p = _peersByCentral[central.identifier];
	if (!p) {
		return;
	}
	[_peersByCentral removeObjectForKey:central.identifier];
	[_peersById removeObjectForKey:@(p.peerId)];
	[self emit:"peer_disconnected" args:Vector<Variant>({ p.peerId })];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests {
	CBUUID *rxId = [CBUUID UUIDWithString:kRx];
	for (CBATTRequest *req in requests) {
		if (![req.characteristic.UUID isEqual:rxId] || !req.value) {
			continue;
		}
		RPPeer *p = _peersByCentral[req.central.identifier];
		if (!p) {
			continue;
		}
		NSData *whole = [p.rx add:req.value];
		if (whole) {
			[self emit:"packet_received" args:Vector<Variant>({ p.peerId, to_bytes(whole) })];
		}
	}
	if (requests.count > 0) {
		[peripheral respondToRequest:requests.firstObject withResult:CBATTErrorSuccess];
	}
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request {
	request.value = [NSData data];
	[peripheral respondToRequest:request withResult:CBATTErrorSuccess];
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral {
	for (RPPeer *p in _peersById.allValues) {
		[self pumpPeer:p];
	}
}

- (void)sendToPeer:(int)peerId data:(NSData *)data {
	RPPeer *p = _peersById[@(peerId)];
	if (!p || !_txChar) {
		return;
	}
	NSUInteger chunk = p.central.maximumUpdateValueLength > 1 ? p.central.maximumUpdateValueLength - 1 : 19;
	for (NSData *f in fragment(data, chunk)) {
		if (p.queue.count >= kMaxQueue) {
			[p.queue removeAllObjects];   // hopelessly behind: start fresh rather than lag forever
		}
		[p.queue addObject:f];
	}
	[self pumpPeer:p];
}

- (void)pumpPeer:(RPPeer *)p {
	while (p.queue.count > 0) {
		BOOL sent = [_peripheralManager updateValue:p.queue.firstObject forCharacteristic:_txChar onSubscribedCentrals:@[ p.central ]];
		if (!sent) {
			return;   // the send queue is full: peripheralManagerIsReadyToUpdateSubscribers resumes
		}
		[p.queue removeObjectAtIndex:0];
	}
}

- (void)stopHosting {
	if (_peripheralManager) {
		if (_advertising) {
			[_peripheralManager stopAdvertising];
		}
		[_peripheralManager removeAllServices];
	}
	_advertising = NO;
	_txChar = nil;
	[_peersByCentral removeAllObjects];
	[_peersById removeAllObjects];
}

// ---------------------------------------------------------------- client
- (void)scanStart {
	[self ensureCentral];
	_scanWanted = YES;
	if (_centralManager.state == CBManagerStatePoweredOn && !_scanning) {
		[self startScanNow];
	}
}

- (void)startScanNow {
	[_lastSeen removeAllObjects];
	[_centralManager scanForPeripheralsWithServices:@[ [CBUUID UUIDWithString:kService] ]
											options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
	_scanning = YES;
}

- (void)scanStop {
	_scanWanted = NO;
	if (_scanning && _centralManager) {
		[_centralManager stopScan];
	}
	_scanning = NO;
}

- (void)centralManager:(CBCentralManager *)central
	didDiscoverPeripheral:(CBPeripheral *)peripheral
		advertisementData:(NSDictionary<NSString *, id> *)adv
					 RSSI:(NSNumber *)RSSI {
	if (!_scanning) {
		return;
	}
	NSString *addr = peripheral.identifier.UUIDString;
	_known[addr] = peripheral;
	NSDate *prev = _lastSeen[addr];
	if (prev && -[prev timeIntervalSinceNow] < kSameRoomGap) {
		return;
	}
	_lastSeen[addr] = [NSDate date];
	NSString *name = @"";
	int players = 1;
	int maxPlayers = 2;
	NSDictionary *serviceData = adv[CBAdvertisementDataServiceDataKey];
	NSData *sd = serviceData[[CBUUID UUIDWithString:kService]];
	if (sd.length >= 3) {
		// an Android host: version, players, max, name
		const uint8_t *b = (const uint8_t *)sd.bytes;
		players = b[1];
		maxPlayers = b[2];
		name = [[NSString alloc] initWithBytes:b + 3 length:sd.length - 3 encoding:NSASCIIStringEncoding] ?: @"";
	} else {
		NSString *local = adv[CBAdvertisementDataLocalNameKey];
		if ([local hasPrefix:@"RP:"]) {
			name = [local substringFromIndex:3];
		} else if (local) {
			name = local;
		}
	}
	[self emit:"room_found" args:Vector<Variant>({ to_godot(addr), to_godot(name), players, maxPlayers, RSSI.intValue })];
}

- (void)join:(NSString *)address {
	[self scanStop];
	[self closeClient];
	CBPeripheral *p = _known[address];
	if (!p) {
		NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:address];
		p = uuid ? [_centralManager retrievePeripheralsWithIdentifiers:@[ uuid ]].firstObject : nil;
	}
	if (!p || _centralManager.state != CBManagerStatePoweredOn) {
		[self emit:"join_failed" args:Vector<Variant>({ String("Could not reach that phone") })];
		return;
	}
	_hostPeripheral = p;
	p.delegate = self;
	_joined = NO;
	[_centralManager connectPeripheral:p options:nil];
	NSUInteger token = ++_joinToken;
	__weak RPBleCore *weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kJoinTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		RPBleCore *s = weakSelf;
		if (s && s.joinToken == token && !s.joined && s.hostPeripheral) {
			[s closeClient];
			[s emit:"join_failed" args:Vector<Variant>({ String("Could not reach that phone") })];
		}
	});
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
	if (peripheral != _hostPeripheral) {
		return;
	}
	[peripheral discoverServices:@[ [CBUUID UUIDWithString:kService] ]];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
	if (peripheral != _hostPeripheral) {
		return;
	}
	[self closeClient];
	[self emit:"join_failed" args:Vector<Variant>({ String("Could not reach that phone") })];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
	if (peripheral != _hostPeripheral) {
		return;
	}
	BOOL was = _joined;
	[self closeClient];
	if (was) {
		[self emit:"host_lost" args:Vector<Variant>({ String("Lost the host") })];
	} else {
		[self emit:"join_failed" args:Vector<Variant>({ String("Could not reach that phone") })];
	}
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
	CBUUID *svcId = [CBUUID UUIDWithString:kService];
	for (CBService *s in peripheral.services) {
		if ([s.UUID isEqual:svcId]) {
			[peripheral discoverCharacteristics:@[ [CBUUID UUIDWithString:kTx], [CBUUID UUIDWithString:kRx] ] forService:s];
			return;
		}
	}
	[self closeClient];
	[self emit:"join_failed" args:Vector<Variant>({ String("That phone isn't hosting a match") })];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
	for (CBCharacteristic *c in service.characteristics) {
		if ([c.UUID isEqual:[CBUUID UUIDWithString:kTx]]) {
			_hostTx = c;
		} else if ([c.UUID isEqual:[CBUUID UUIDWithString:kRx]]) {
			_hostRx = c;
		}
	}
	if (!_hostTx || !_hostRx) {
		[self closeClient];
		[self emit:"join_failed" args:Vector<Variant>({ String("That phone isn't hosting a match") })];
		return;
	}
	[peripheral setNotifyValue:YES forCharacteristic:_hostTx];
}

- (void)peripheral:(CBPeripheral *)peripheral
	didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
										  error:(NSError *)error {
	if (characteristic != _hostTx || _joined) {
		return;
	}
	if (error || !characteristic.isNotifying) {
		[self closeClient];
		[self emit:"join_failed" args:Vector<Variant>({ String("Could not reach that phone") })];
		return;
	}
	_joined = YES;
	[self emit:"joined" args:Vector<Variant>()];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
	if (characteristic != _hostTx || !characteristic.value) {
		return;
	}
	NSData *whole = [_clientRx add:characteristic.value];
	if (whole) {
		[self emit:"packet_received" args:Vector<Variant>({ kHostId, to_bytes(whole) })];
	}
}

- (void)sendToHost:(NSData *)data {
	if (!_joined || !_hostRx) {
		return;
	}
	NSUInteger max = [_hostPeripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithResponse];
	for (NSData *f in fragment(data, max > 1 ? max - 1 : 19)) {
		if (_clientQueue.count >= kMaxQueue) {
			[_clientQueue removeAllObjects];
		}
		[_clientQueue addObject:f];
	}
	[self pumpClient];
}

- (void)pumpClient {
	if (_writing || _clientQueue.count == 0 || !_hostRx) {
		return;
	}
	_writing = YES;
	[_hostPeripheral writeValue:_clientQueue.firstObject forCharacteristic:_hostRx type:CBCharacteristicWriteWithResponse];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
	_writing = NO;
	if (_clientQueue.count > 0) {
		[_clientQueue removeObjectAtIndex:0];
	}
	[self pumpClient];
}

- (void)closeClient {
	_joinToken++;
	if (_hostPeripheral && _centralManager) {
		[_centralManager cancelPeripheralConnection:_hostPeripheral];
	}
	_hostPeripheral.delegate = nil;
	_hostPeripheral = nil;
	_hostTx = nil;
	_hostRx = nil;
	_joined = NO;
	_writing = NO;
	[_clientQueue removeAllObjects];
	_clientRx = [[RPReassembler alloc] init];
}

- (void)closeAll {
	_hostWanted = NO;
	[self scanStop];
	[self closeClient];
	[self stopHosting];
}

@end

// ---------------------------------------------------------------- the Godot singleton
RetroPoloBLE::RetroPoloBLE() {
	core = [[RPBleCore alloc] initWithOwner:this];
}

RetroPoloBLE::~RetroPoloBLE() {
	if (core) {
		[core closeAll];
		core.owner = nullptr;
		core = nil;
	}
}

String RetroPoloBLE::getStatus() {
	return to_godot([core status]);
}

void RetroPoloBLE::requestAccess() {
	[core requestAccess];
}

void RetroPoloBLE::hostStart(String p_name, int p_max_players) {
	[core hostStart:to_ns(p_name) maxPlayers:p_max_players];
}

void RetroPoloBLE::setRoomInfo(int p_players) {
	// iOS adverts carry only the room name; the lobby tells joiners the rest
}

void RetroPoloBLE::scanStart() {
	[core scanStart];
}

void RetroPoloBLE::scanStop() {
	[core scanStop];
}

void RetroPoloBLE::join(String p_address) {
	[core join:to_ns(p_address)];
}

void RetroPoloBLE::send(int p_to, PackedByteArray p_data) {
	NSData *d = [NSData dataWithBytes:p_data.ptr() length:p_data.size()];
	if (p_to == kHostId) {
		[core sendToHost:d];
	} else {
		[core sendToPeer:p_to data:d];
	}
}

void RetroPoloBLE::close() {
	[core closeAll];
}

void RetroPoloBLE::_bind_methods() {
	ClassDB::bind_method(D_METHOD("getStatus"), &RetroPoloBLE::getStatus);
	ClassDB::bind_method(D_METHOD("requestAccess"), &RetroPoloBLE::requestAccess);
	ClassDB::bind_method(D_METHOD("hostStart", "name", "max_players"), &RetroPoloBLE::hostStart);
	ClassDB::bind_method(D_METHOD("setRoomInfo", "players"), &RetroPoloBLE::setRoomInfo);
	ClassDB::bind_method(D_METHOD("scanStart"), &RetroPoloBLE::scanStart);
	ClassDB::bind_method(D_METHOD("scanStop"), &RetroPoloBLE::scanStop);
	ClassDB::bind_method(D_METHOD("join", "address"), &RetroPoloBLE::join);
	ClassDB::bind_method(D_METHOD("send", "to", "data"), &RetroPoloBLE::send);
	ClassDB::bind_method(D_METHOD("close"), &RetroPoloBLE::close);

	ADD_SIGNAL(MethodInfo("status_changed", PropertyInfo(Variant::STRING, "status")));
	ADD_SIGNAL(MethodInfo("room_found", PropertyInfo(Variant::STRING, "address"), PropertyInfo(Variant::STRING, "name"),
			PropertyInfo(Variant::INT, "players"), PropertyInfo(Variant::INT, "max_players"), PropertyInfo(Variant::INT, "rssi")));
	ADD_SIGNAL(MethodInfo("joined"));
	ADD_SIGNAL(MethodInfo("join_failed", PropertyInfo(Variant::STRING, "reason")));
	ADD_SIGNAL(MethodInfo("host_lost", PropertyInfo(Variant::STRING, "reason")));
	ADD_SIGNAL(MethodInfo("host_failed", PropertyInfo(Variant::STRING, "reason")));
	ADD_SIGNAL(MethodInfo("peer_connected", PropertyInfo(Variant::INT, "id")));
	ADD_SIGNAL(MethodInfo("peer_disconnected", PropertyInfo(Variant::INT, "id")));
	ADD_SIGNAL(MethodInfo("packet_received", PropertyInfo(Variant::INT, "from"), PropertyInfo(Variant::PACKED_BYTE_ARRAY, "data")));
}
