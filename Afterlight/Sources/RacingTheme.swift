import SwiftUI

/// Shared visual language: graphite, warm alloy, racing numerals and clipped panels.
enum RacingType {
    static func title(_ size:CGFloat) -> Font { .system(size:size,weight:.heavy,design:.default).width(.condensed).italic() }
    static func data(_ size:CGFloat) -> Font { .system(size:size,weight:.semibold,design:.monospaced) }
}
struct RacingPanel: Shape {
    var cut:CGFloat=12
    func path(in rect:CGRect) -> Path { Path { p in p.move(to:CGPoint(x:0,y:0));p.addLine(to:CGPoint(x:rect.maxX-cut,y:0));p.addLine(to:CGPoint(x:rect.maxX,y:cut));p.addLine(to:CGPoint(x:rect.maxX,y:rect.maxY));p.addLine(to:CGPoint(x:cut,y:rect.maxY));p.addLine(to:CGPoint(x:0,y:rect.maxY-cut));p.closeSubpath() } }
}
struct PaddockBackground: View {
    var body:some View { Canvas { context,size in
        context.fill(Path(CGRect(origin:.zero,size:size)),with:.color(ink))
        var grid=Path()
        for x in stride(from:CGFloat(0),through:size.width,by:28) { grid.move(to:CGPoint(x:x,y:0));grid.addLine(to:CGPoint(x:x,y:size.height)) }
        for y in stride(from:CGFloat(0),through:size.height,by:28) {grid.move(to:CGPoint(x:0,y:y));grid.addLine(to:CGPoint(x:size.width,y:y))}
        context.stroke(grid,with:.color(.white.opacity(0.025)),lineWidth:0.5)
    }.ignoresSafeArea().allowsHitTesting(false) }
}
struct SectionHeading: View {
    let number:String;let title:String;var detail:String=""
    var body:some View { HStack(alignment:.firstTextBaseline,spacing:10) { Text(number).font(RacingType.data(10)).foregroundStyle(mint);Text(title).font(RacingType.title(27));Spacer();if !detail.isEmpty {Text(detail).font(RacingType.data(9)).foregroundStyle(muted)} }.padding(.vertical,6).overlay(alignment:.bottom) { Rectangle().fill(.white.opacity(0.12)).frame(height:1) } }
}
struct TelemetryBar: View {
    let value:Double; var color=mint
    var body:some View { HStack(spacing:3) { ForEach(0..<20,id:\.self) { i in Rectangle().fill(Double(i)/20<value ? color : .white.opacity(0.07)) } }.frame(height:7) }
}

struct CircuitArtwork: View {
    let circuit:Circuit
    var body:some View {
        GeometryReader { size in ZStack(alignment:.bottomLeading) {
            if let image=SurfaceLibrary.image("circuit-\(circuit.id)") {Image(uiImage:image).resizable().scaledToFill().frame(width:size.size.width,height:size.size.height).clipped()}
            else {Color(hex:circuit.sky);TrackMap(circuit:circuit).padding(20)}
            LinearGradient(colors:[.clear,.black.opacity(0.55)],startPoint:.center,endPoint:.bottom)
            Text(circuit.look.setting).font(RacingType.data(8)).tracking(1).padding(9).foregroundStyle(.white)
        }}.accessibilityHidden(true)
    }
}
