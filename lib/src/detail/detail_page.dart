import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:snapd/snapd.dart';
import 'package:ubuntu_widgets/ubuntu_widgets.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:yaru/yaru.dart';
import 'package:yaru_icons/yaru_icons.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

import '/l10n.dart';
import '/layout.dart';
import '/snapd.dart';
import '/widgets.dart';

const _kPrimaryButtonMaxWidth = 136.0;
const _kChannelDropdownWidth = 220.0;

typedef SnapInfo = ({String label, Widget value});

class DetailPage extends ConsumerWidget {
  const DetailPage({super.key, required this.snapName});

  final String snapName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapModel = ref.watch(snapModelProvider(snapName));
    final updatesModel = ref.watch(updatesModelProvider);
    return snapModel.state.when(
      data: (_) => ResponsiveLayoutBuilder(
        builder: (_) => _SnapView(
          snapModel: snapModel,
          updatesModel: updatesModel,
        ),
      ),
      error: (error, stackTrace) => ErrorWidget(error),
      loading: () => const Center(child: YaruCircularProgressIndicator()),
    );
  }
}

class _SnapView extends ConsumerWidget {
  const _SnapView({required this.snapModel, required this.updatesModel});

  final SnapModel snapModel;
  final UpdatesModel updatesModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final snapInfos = <SnapInfo>[
      (
        label: '123 Ratings',
        value: Text(
          'Positive',
          style: TextStyle(color: Theme.of(context).colorScheme.success),
        )
      ), // Placeholder
      (
        label: l10n.detailPageConfinementLabel,
        value: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              snapModel.channelInfo?.confinement.localize(l10n) ??
                  snapModel.snap.confinement.localize(l10n),
            ),
            if ((snapModel.channelInfo?.confinement ??
                    snapModel.snap.confinement) ==
                SnapConfinement.strict) ...const [
              SizedBox(width: 2),
              Icon(YaruIcons.shield, size: 12),
            ],
          ],
        ),
      ),
      (
        label: l10n.detailPageDownloadSizeLabel,
        value: Text(
          snapModel.channelInfo != null
              ? context.formatByteSize(snapModel.channelInfo!.size)
              : '',
        )
      ),
      (
        label: l10n.detailPagePublishedLabel,
        value: Text(
          snapModel.channelInfo != null
              ? DateFormat.yMMMd().format(snapModel.channelInfo!.releasedAt)
              : '',
        ),
      ),
      (
        label: l10n.detailPageLicenseLabel,
        value: Text(snapModel.snap.license ?? ''),
      ),
      (
        label: l10n.detailPageLinksLabel,
        value: Column(
          children: [
            if (snapModel.snap.website != null)
              '<a href="${snapModel.snap.website}">${l10n.detailPageDeveloperWebsiteLabel}</a>',
            if (snapModel.snap.contact != null &&
                snapModel.snap.publisher != null)
              '<a href="${snapModel.snap.contact}">${l10n.detailPageContactPublisherLabel(snapModel.snap.publisher!.displayName)}</a>'
          ]
              .map((link) => Html(
                    data: link,
                    style: {'body': Style(margin: Margins.zero)},
                    onLinkTap: (url, attributes, element) =>
                        launchUrlString(url!),
                  ))
              .toList(),
        ),
      ),
    ];

    final layout = ResponsiveLayout.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kPagePadding),
      child: Column(
        children: [
          SizedBox(
            width: layout.totalWidth,
            child: _Header(snapModel: snapModel),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: layout.totalWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SnapInfos(snapInfos: snapInfos, layout: layout),
                      const Divider(),
                      if (snapModel.hasGallery)
                        _Section(
                          header: Text(l10n.detailPageGalleryLabel),
                          child: SnapScreenshotGallery(
                            snap: snapModel.storeSnap!,
                            height: layout.totalWidth / 2,
                          ),
                        ),
                      _Section(
                        header: Text(l10n.detailPageDescriptionLabel),
                        child: SizedBox(
                          width: double.infinity,
                          child: MarkdownBody(
                            data: snapModel.storeSnap?.description ??
                                snapModel.localSnap?.description ??
                                '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapInfos extends StatelessWidget {
  const _SnapInfos({
    required this.snapInfos,
    required this.layout,
  });

  final List<SnapInfo> snapInfos;
  final ResponsiveLayout layout;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: kPagePadding,
      runSpacing: 8,
      children: snapInfos
          .map((info) => SizedBox(
                width: (layout.totalWidth -
                        (layout.snapInfoColumnCount - 1) * kPagePadding) /
                    layout.snapInfoColumnCount,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.label),
                    DefaultTextStyle.merge(
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      child: info.value,
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _SnapActionButtons extends ConsumerWidget {
  const _SnapActionButtons({required this.snapModel});

  final SnapModel snapModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapLauncher = snapModel.isInstalled
        ? ref.watch(launchProvider(snapModel.localSnap!))
        : null;
    final updatesModel = ref.watch(updatesModelProvider);

    final primaryAction = snapModel.isInstalled
        ? snapModel.selectedChannel == snapModel.localSnap!.trackingChannel
            ? SnapAction.open
            : SnapAction.switchChannel
        : SnapAction.install;
    final primaryActionButton = SizedBox(
      width: _kPrimaryButtonMaxWidth,
      child: PushButton.elevated(
        onPressed: snapModel.activeChangeId != null
            ? null
            : primaryAction.callback(snapModel, snapLauncher),
        child: snapModel.activeChangeId != null
            ? Consumer(
                builder: (context, ref, child) {
                  final change = ref
                      .watch(changeProvider(snapModel.activeChangeId))
                      .whenOrNull(data: (data) => data);
                  return Row(
                    children: [
                      SizedBox.square(
                        dimension: 16,
                        child: YaruCircularProgressIndicator(
                          value: change?.progress,
                          strokeWidth: 2,
                        ),
                      ),
                      if (change != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            change.localize(l10n) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]
                    ],
                  );
                },
              )
            : Text(primaryAction.label(l10n)),
      ),
    );

    final secondaryActions = [
      if (updatesModel.hasUpdate(snapModel.snapName)) SnapAction.update,
      SnapAction.remove,
    ];
    final secondaryActionsButton = MenuAnchor(
      menuChildren: secondaryActions.map((action) {
        final color = action == SnapAction.remove
            ? Theme.of(context).colorScheme.error
            : null;
        return MenuItemButton(
          child: IntrinsicWidth(
            child: ListTile(
              leading: action.icon != null
                  ? Icon(
                      action.icon,
                      color: color,
                    )
                  : null,
              title: Text(
                action.label(l10n),
                style: TextStyle(color: color),
              ),
            ),
          ),
          onPressed: () => action.callback(snapModel)?.call(),
        );
      }).toList(),
      builder: (context, controller, child) => YaruOptionButton(
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        child: const Icon(YaruIcons.view_more_horizontal),
      ),
    );

    final cancelButton = OutlinedButton(
      onPressed: SnapAction.cancel.callback(snapModel),
      child: Text(SnapAction.cancel.label(l10n)),
    );

    return ButtonBar(
      mainAxisSize: MainAxisSize.min,
      overflowButtonSpacing: 8,
      children: [
        primaryActionButton,
        if (snapModel.activeChangeId != null)
          cancelButton
        else if (snapModel.isInstalled)
          secondaryActionsButton,
      ].whereNotNull().toList(),
    );
  }
}

enum SnapAction {
  cancel,
  install,
  open,
  remove,
  switchChannel,
  update;

  String label(AppLocalizations l10n) => switch (this) {
        cancel => l10n.snapActionCancelLabel,
        install => l10n.snapActionInstallLabel,
        open => l10n.snapActionOpenLabel,
        remove => l10n.snapActionRemoveLabel,
        switchChannel => l10n.snapActionSwitchChannelLabel,
        update => l10n.snapActionUpdateLabel,
      };

  IconData? get icon => switch (this) {
        update => YaruIcons.refresh,
        remove => YaruIcons.trash,
        _ => null,
      };

  VoidCallback? callback(SnapModel model, [SnapLauncher? launcher]) =>
      switch (this) {
        cancel => model.cancel,
        install => model.install,
        open => launcher?.isLaunchable ?? false ? launcher!.open : null,
        remove => model.remove,
        switchChannel => model.refresh,
        update => model.refresh,
      };
}

class _Section extends YaruExpandable {
  const _Section({required super.header, required super.child})
      : super(
          expandButtonPosition: YaruExpandableButtonPosition.start,
          isExpanded: true,
        );
}

class _Header extends StatelessWidget {
  const _Header({required this.snapModel});

  final SnapModel snapModel;

  @override
  Widget build(BuildContext context) {
    final snap = snapModel.storeSnap ?? snapModel.localSnap!;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const YaruBackButton(),
            if (snap.website != null)
              YaruIconButton(
                icon: const Icon(YaruIcons.share),
                onPressed: () {
                  // TODO show snackbar
                  Clipboard.setData(ClipboardData(text: snap.website!));
                },
              ),
          ],
        ),
        const SizedBox(height: kPagePadding),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SnapIcon(iconUrl: snap.iconUrl, size: 96),
            const SizedBox(width: 16),
            Expanded(child: SnapTitle.large(snap: snap)),
          ],
        ),
        const SizedBox(height: kPagePadding),
        Row(
          children: [
            if (snapModel.availableChannels != null &&
                snapModel.selectedChannel != null) ...[
              _ChannelDropdown(model: snapModel),
              const SizedBox(width: 16),
            ],
            Flexible(child: _SnapActionButtons(snapModel: snapModel))
          ],
        ),
        const SizedBox(height: 42),
        const Divider(),
      ],
    );
  }
}

class _ChannelDropdown extends StatelessWidget {
  const _ChannelDropdown({required this.model});

  final SnapModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.detailPageChannelLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: _kChannelDropdownWidth,
          child: MenuButtonBuilder(
            entries: model.availableChannels!.entries
                .map(
              (channelEntry) => MenuButtonEntry(
                value: channelEntry.key,
                child: _ChannelDropdownEntry(channelEntry: channelEntry),
              ),
            )
                .fold(
              <MenuButtonEntry<String>>[],
              (p, e) =>
                  [...p, e, const MenuButtonEntry(value: '', isDivider: true)],
            )..removeLast(),
            itemBuilder: (context, value, child) => Text(value),
            selected: model.selectedChannel,
            onSelected: (value) => model.selectedChannel = value,
            menuPosition: PopupMenuPosition.under,
            menuStyle: const MenuStyle(
              minimumSize:
                  MaterialStatePropertyAll(Size(_kChannelDropdownWidth, 0)),
              maximumSize:
                  MaterialStatePropertyAll(Size(_kChannelDropdownWidth, 200)),
              visualDensity: VisualDensity(horizontal: 0, vertical: 0),
            ),
            itemStyle: MenuItemButton.styleFrom(),
            child: Text(
              "${model.selectedChannel} ${model.availableChannels![model.selectedChannel]!.version}",
            ),
          ),
        ),
      ],
    );
  }
}

class _ChannelDropdownEntry extends StatelessWidget {
  const _ChannelDropdownEntry({required this.channelEntry});

  final MapEntry<String, SnapChannel> channelEntry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            overflow: TextOverflow.ellipsis,
          ),
      child: SizedBox(
        width: _kChannelDropdownWidth - 24,
        child: Row(
          children: [
            DefaultTextStyle.merge(
              style: TextStyle(
                color: Theme.of(context).hintColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.detailPageChannelLabel),
                  Text(l10n.detailPageVersionLabel),
                  Text(l10n.detailPagePublishedLabel),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  channelEntry.key,
                  channelEntry.value.version,
                  DateFormat.yMd().format(channelEntry.value.releasedAt),
                ].map((e) => Text(e, maxLines: 1)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
