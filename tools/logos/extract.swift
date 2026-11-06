import Foundation
import CoreGraphics
import AppKit
// Walk each page's content stream; on every image Do, record CTM and dump the image.
let args = CommandLine.arguments
let doc = CGPDFDocument(URL(fileURLWithPath: args[1]) as CFURL)!
let out = args[2]
struct St { var ctm: CGAffineTransform }
final class Ctx { var stack: [CGAffineTransform] = [.identity]; var page = 0; var n = 0; var xobjs: CGPDFDictionaryRef? }
let table = CGPDFOperatorTableCreate()!
CGPDFOperatorTableSetCallback(table, "q") { s, info in let c = Unmanaged<Ctx>.fromOpaque(info!).takeUnretainedValue(); c.stack.append(c.stack.last!) }
CGPDFOperatorTableSetCallback(table, "Q") { s, info in let c = Unmanaged<Ctx>.fromOpaque(info!).takeUnretainedValue(); if c.stack.count > 1 { c.stack.removeLast() } }
CGPDFOperatorTableSetCallback(table, "cm") { s, info in
  let c = Unmanaged<Ctx>.fromOpaque(info!).takeUnretainedValue()
  var v = [CGPDFReal](repeating: 0, count: 6)
  for i in (0..<6).reversed() { CGPDFScannerPopNumber(s, &v[i]) }
  let m = CGAffineTransform(a: v[0], b: v[1], c: v[2], d: v[3], tx: v[4], ty: v[5])
  c.stack[c.stack.count-1] = m.concatenating(c.stack.last!)
}
CGPDFOperatorTableSetCallback(table, "Do") { s, info in
  let c = Unmanaged<Ctx>.fromOpaque(info!).takeUnretainedValue()
  var name: UnsafePointer<CChar>? = nil
  CGPDFScannerPopName(s, &name)
  var stream: CGPDFStreamRef? = nil
  guard let xo = c.xobjs, CGPDFDictionaryGetStream(xo, name!, &stream) else { return }
  let d = CGPDFStreamGetDictionary(stream!)!
  var sub: UnsafePointer<CChar>? = nil
  CGPDFDictionaryGetName(d, "Subtype", &sub)
  guard String(cString: sub!) == "Image" else { return }
  var w: CGPDFInteger = 0, h: CGPDFInteger = 0, bpc: CGPDFInteger = 0
  CGPDFDictionaryGetInteger(d, "Width", &w); CGPDFDictionaryGetInteger(d, "Height", &h); CGPDFDictionaryGetInteger(d, "BitsPerComponent", &bpc)
  var fmt = CGPDFDataFormat.raw
  let data = CGPDFStreamCopyData(stream!, &fmt)! as Data
  c.n += 1
  let m = c.stack.last!
  let base = "\(out)/p\(c.page)_\(c.n)"
  print("p\(c.page)_\(c.n) \(w)x\(h) bpc=\(bpc) fmt=\(fmt.rawValue) rect x=\(Int(m.tx)) y=\(Int(m.ty)) w=\(Int(m.a)) h=\(Int(m.d))")
  if fmt == .jpegEncoded || fmt == .JPEG2000 { try! data.write(to: URL(fileURLWithPath: base + (fmt == .jpegEncoded ? ".jpg" : ".jp2"))) }
  else { try! data.write(to: URL(fileURLWithPath: base + ".raw")) }
}
for p in 1...doc.numberOfPages {
  let page = doc.page(at: p)!
  let c = Ctx(); c.page = p
  let pd = page.dictionary!
  var res: CGPDFDictionaryRef? = nil
  CGPDFDictionaryGetDictionary(pd, "Resources", &res)
  var xo: CGPDFDictionaryRef? = nil
  if let r = res { CGPDFDictionaryGetDictionary(r, "XObject", &xo) }
  c.xobjs = xo
  let cs = CGPDFContentStreamCreateWithPage(page)
  let sc = CGPDFScannerCreate(cs, table, Unmanaged.passUnretained(c).toOpaque())
  CGPDFScannerScan(sc)
}
