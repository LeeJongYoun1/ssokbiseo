import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

const kNeedPlaces = '설정에서 집·회사를 등록해 주세요';
const kNeedPermission = '권한을 허용하면 볼 수 있어요';

Future<bool> openExternal(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

class CardShell extends StatelessWidget {
  final String title;
  final bool stale;
  final List<Widget> children;
  const CardShell(this.title, this.children, {this.stale = false, super.key});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (stale)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('어제 내용이에요',
                    style: TextStyle(fontSize: 15, color: SsokColors.inkSub)),
              ),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );
}

Widget bodyText(String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(s, style: const TextStyle(fontSize: 17, height: 1.4)));

/// Future 하나를 로딩/실패/완료로 그린다 — 카드마다 따로 실패한다.
class CardFuture<T> extends StatelessWidget {
  final Future<T> future;
  final String error;
  final Widget Function(T) builder;
  const CardFuture(this.future, this.error, this.builder, {super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (_, s) {
          if (s.hasError) return bodyText(error);
          if (s.connectionState != ConnectionState.done) {
            return const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator()));
          }
          return builder(s.data as T);
        },
      );
}

void showDetail(BuildContext context, String title, String summary,
    List<(String, String)> links) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: SsokColors.cream,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(summary, style: const TextStyle(fontSize: 17, height: 1.5)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, children: [
                for (final l in links)
                  if (l.$2.isNotEmpty)
                    FilledButton(onPressed: () => openExternal(l.$2), child: Text(l.$1)),
              ]),
            ]),
      ),
    ),
  );
}
