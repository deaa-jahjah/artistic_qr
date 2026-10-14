import 'package:flutter/widgets.dart';

import '../encoder/qr_encoder.dart';
import '../encoder/tables.dart';
import '../image/qr_image.dart';
import '../image/qr_image_renderer.dart';
import '../style/qr_frame.dart';
import '../style/qr_style.dart';
import 'qr_painter.dart';

/// Displays an artistic QR code encoding [data].
///
/// ```dart
/// ArtisticQrCode(
///   data: 'https://example.com',
///   size: 280,
///   style: QrStyle(
///     moduleShape: ModuleShape.circle,
///     fill: QrFill.linearGradient(colors: [Colors.indigo, Colors.purple]),
///   ),
/// )
/// ```
class ArtisticQrCode extends StatefulWidget {
  const ArtisticQrCode({
    super.key,
    required this.data,
    this.size,
    this.errorCorrection = QrErrorCorrection.quartile,
    this.style = const QrStyle(),
    this.frame,
    this.image,
    this.errorBuilder,
    this.semanticsLabel,
  });

  /// The text encoded in the symbol.
  final String data;

  /// Width and height. When null, the widget expands to its constraints.
  final double? size;

  final QrErrorCorrection errorCorrection;
  final QrStyle style;

  /// Optional decorative border + "SCAN ME" banner around the code.
  final QrFrame? frame;

  /// Optional embedded image (logo, color blend, or halftone photo).
  /// While the image loads, the plain styled code is shown.
  final QrImage? image;

  /// Built instead of the code when encoding fails (e.g. data too long).
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Accessibility label; defaults to "QR code".
  final String? semanticsLabel;

  @override
  State<ArtisticQrCode> createState() => _ArtisticQrCodeState();
}

class _ArtisticQrCodeState extends State<ArtisticQrCode> {
  QrCode? _code;
  Object? _error;
  QrImageRenderData? _imageData;
  int _imageRequest = 0;
  bool _dependenciesChanged = false;

  @override
  void initState() {
    super.initState();
    _encode();
    // 将 _resolveImage 移到 didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 只在首次或依赖变化时加载图片
    if (!_dependenciesChanged) {
      _dependenciesChanged = true;
      _resolveImage();
    }
  }

  @override
  void didUpdateWidget(ArtisticQrCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reencode =
        oldWidget.data != widget.data ||
        oldWidget.errorCorrection != widget.errorCorrection;
    if (reencode) _encode();
    // 如果 image 变化，重新加载
    if (oldWidget.image != widget.image) {
      _resolveImage();
    }
  }

  void _encode() {
    try {
      _code = QrCode.encode(
        widget.data,
        errorCorrection: widget.errorCorrection,
      );
      _error = null;
    } catch (e) {
      _code = null;
      _error = e;
    }
  }

  Future<void> _resolveImage() async {
    final request = ++_imageRequest;
    final image = widget.image;
    final code = _code;
    _imageData = null;
    if (image == null || code == null) return;
    try {
      final pixels = await image.source.resolve(
        configuration: createLocalImageConfiguration(context),
      );
      final data = buildImageRenderData(
        code: code,
        style: widget.style,
        image: ResolvedQrImage(pixels: pixels, mode: image.mode),
      );
      if (mounted && request == _imageRequest) {
        setState(() => _imageData = data);
      }
    } catch (e) {
      // Image failed to load: keep showing the plain styled code.
      // 可以添加日志或错误处理
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final builder = widget.errorBuilder;
      if (builder != null) return builder(context, _error!);
      return SizedBox.square(dimension: widget.size);
    }
    final imageData = _imageData;
    return Semantics(
      label: widget.semanticsLabel ?? 'QR code',
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      image: true,
      child: CustomPaint(
        size: widget.size != null ? Size.square(widget.size!) : Size.infinite,
        painter: imageData == null
            ? QrPainter(code: _code!, style: widget.style, frame: widget.frame)
            : QrPainter.withImage(
                code: _code!,
                style: widget.style,
                frame: widget.frame,
                imageData: imageData,
              ),
      ),
    );
  }
}
