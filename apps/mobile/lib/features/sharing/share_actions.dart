import 'package:flutter/material.dart';

import '../../core/session/session_scope.dart';
import '../cagnottes/cagnotte.dart';
import '../organizations/organization.dart';
import '../tontines/models.dart';
import 'share_sheet.dart';
import 'sharing_repository.dart';

/// Points d'entrée du partage : un appel d'une ligne depuis les écrans.

Future<void> shareTontine(
  BuildContext context,
  Tontine tontine, {
  required Organization organization,
  VoidCallback? onChanged,
}) {
  final sharing = SharingRepository(SessionScope.read(context).api);

  return showShareSheet(
    context,
    title: tontine.name,
    subject: 'la tontine ${tontine.name}',
    visibility: tontine.visibility,
    shareUrl: tontine.shareUrl,
    canManage: organization.role.canManage,
    onVisibilityChanged: (visibility) async {
      final url = await sharing.setTontine(organization.id, tontine.id, visibility);
      onChanged?.call();

      return url;
    },
  );
}

Future<void> shareCagnotte(
  BuildContext context,
  Cagnotte cagnotte, {
  required int organizationId,
  required bool canManage,
  VoidCallback? onChanged,
}) {
  final sharing = SharingRepository(SessionScope.read(context).api);

  return showShareSheet(
    context,
    title: cagnotte.title,
    subject: 'la cagnotte ${cagnotte.title}',
    visibility: cagnotte.visibility,
    shareUrl: cagnotte.shareUrl,
    canManage: canManage,
    onVisibilityChanged: (visibility) async {
      final url = await sharing.setCagnotte(organizationId, cagnotte.id, visibility);
      onChanged?.call();

      return url;
    },
  );
}

Future<void> shareOrganization(BuildContext context, Organization organization, {VoidCallback? onChanged}) {
  final session = SessionScope.read(context);
  final sharing = SharingRepository(session.api);

  return showShareSheet(
    context,
    title: organization.name,
    subject: organization.name,
    visibility: organization.visibility,
    shareUrl: organization.shareUrl,
    canManage: organization.role.canManage,
    onVisibilityChanged: (visibility) async {
      final url = await sharing.setOrganization(organization.id, visibility);
      // La liste des organisations porte la visibilité : elle doit refléter le nouveau réglage.
      await session.reloadOrganizations(select: organization.id);
      onChanged?.call();

      return url;
    },
  );
}
