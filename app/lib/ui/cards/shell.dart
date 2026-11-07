import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

const kNeedPlaces = '설정에서 집·회사를 등록해 주세요';
const kNeedGps = '위치(GPS)를 켜 주세요';
const kNeedPermission = '권한을 허용하면 볼 수 있어요';

Future<bool> openExternal(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

typedef ShareText = Future<void> Function(String text, {String? subject});

Future<void> shareText(String text, {String? subject}) => SharePlus.instance
    .share(ShareParams(text: text, subject: subject))
    .then((_) {});

class CardShell extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const CardShell(this.title, this.children, {super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

/// 홈의 둥근 타일(그림자·카드 테두리 없음). onTap이 있으면 눌림 효과.
class Tile extends StatelessWidget {
  final Color color;
  final BorderSide side;
  final double padding;
  final VoidCallback? onTap;
  final Widget child;
  const Tile({
    required this.color,
    required this.child,
    this.side = BorderSide.none,
    this.padding = 16,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: side,
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
}

Widget bodyText(String s) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Text(s, style: const TextStyle(fontSize: 17, height: 1.4)),
);

/// Future 하나를 로딩/실패/완료로 그린다 — 카드마다 따로 실패한다.
class CardFuture<T> extends StatelessWidget {
  final Future<T> future;
  final String error;
  final Widget? Function(Object)? errorFor; // 오류 종류별 위젯(null이면 기본 문구)
  final Widget Function(T) builder;
  const CardFuture(
    this.future,
    this.error,
    this.builder, {
    this.errorFor,
    super.key,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (_, s) {
      if (s.hasError) return errorFor?.call(s.error!) ?? bodyText(error);
      if (s.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(8),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return builder(s.data as T);
    },
  );
}

void showDetail(
  BuildContext context,
  String title,
  String summary,
  List<(String, String)> links, {
  ShareText share = shareText,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: SsokColors.cream,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(summary, style: const TextStyle(fontSize: 17, height: 1.5)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final l in links)
                    if (l.$2.isNotEmpty)
                      FilledButton(
                        onPressed: () => openExternal(l.$2),
                        child: Text(l.$1),
                      ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('공유하기'),
                    onPressed: () async {
                      final url = links.isEmpty ? '' : links.first.$2;
                      try {
                        await share('$title\n$summary\n$url', subject: title);
                      } catch (_) {
                        if (sheet.mounted) {
                          ScaffoldMessenger.of(sheet).showSnackBar(
                            const SnackBar(content: Text('공유하지 못했어요')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
