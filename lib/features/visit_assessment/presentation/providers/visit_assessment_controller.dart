import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:oruma_app/features/visit_assessment/data/visit_assessment_repository.dart';
import 'package:oruma_app/features/visit_assessment/domain/visit_assessment.dart';

enum AssessmentSyncState { idle, saving, saved, offline, error }

class VisitAssessmentController extends ChangeNotifier {
  VisitAssessmentController({
    required VisitAssessment initialAssessment,
    VisitAssessmentRepository? repository,
  }) : _repository = repository ?? VisitAssessmentRepository(),
       _assessment = initialAssessment,
       _newAssessmentSeed = _identitySeed(initialAssessment),
       _createsHomeVisitOnSubmit = initialAssessment.homeVisitId.trim().isEmpty;

  final VisitAssessmentRepository _repository;
  final VisitAssessment _newAssessmentSeed;
  final bool _createsHomeVisitOnSubmit;
  VisitAssessment _assessment;
  Timer? _autoSaveTimer;
  Timer? _localSaveDebounce;
  final Set<String> _draftKeysSeen = {};
  bool _disposed = false;
  bool _hasUserChanges = false;

  VisitAssessment get assessment => _assessment;
  bool get hasDraftInProgress =>
      _assessment.status != 'submitted' &&
      !_assessment.isComplete &&
      (!_createsHomeVisitOnSubmit ||
          _assessment.homeVisitId.trim().isNotEmpty ||
          _assessment.id != null ||
          _hasUserChanges);

  List<VisitAssessment> previousAssessments = [];
  AssessmentSyncState syncState = AssessmentSyncState.idle;
  String? syncMessage;
  bool isLoading = true;
  bool isSubmitting = false;
  int currentStep = 0;
  String language = 'en';

  bool get isMalayalam => language == 'ml';
  String get _draftKey => VisitAssessmentRepository.draftKeyFor(_assessment);

  Future<void> initialize() async {
    isLoading = true;
    _notify();

    final initialDraftKey = _draftKey;
    _rememberDraftKeysFor(_assessment, extraKeys: [initialDraftKey]);
    final local = await _repository.loadLocalDraft(initialDraftKey);
    var usingLocalDraft = false;
    VisitAssessment? remote;
    if (_assessment.homeVisitId.trim().isNotEmpty) {
      try {
        remote = await _repository.getRemoteForVisit(_assessment.homeVisitId);
      } catch (_) {
        syncState = AssessmentSyncState.offline;
        syncMessage = 'Offline — changes are saved on this device';
      }
    }

    if (remote != null && (remote.status == 'submitted' || remote.isComplete)) {
      _assessment = remote;
      _hasUserChanges = false;
      await _clearLocalDraftsFor(remote, extraKeys: [initialDraftKey]);
    } else if (local != null && remote != null) {
      final localTime =
          local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final remoteTime =
          remote.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      usingLocalDraft = localTime.isAfter(remoteTime);
      _assessment = usingLocalDraft ? local : remote;
      _hasUserChanges = true;
    } else {
      usingLocalDraft = local != null;
      _assessment = local ?? remote ?? _assessment;
      _hasUserChanges =
          local != null ||
          (_assessment.id != null &&
              _assessment.status != 'submitted' &&
              !_assessment.isComplete);
    }

    final history = await _repository.getHistory(_assessment.patientId);
    if (usingLocalDraft &&
        local != null &&
        _hasSubmittedMatch(local, history)) {
      await _clearLocalDraftsFor(local, extraKeys: [initialDraftKey]);
      _assessment = _freshAssessment();
      _hasUserChanges = false;
    }
    _rememberDraftKeysFor(_assessment);
    _setHistory(history);
    isLoading = false;
    _startAutoSave();
    _notify();
  }

  void _setHistory(List<VisitAssessment> assessments) {
    previousAssessments = assessments
        .where(
          (item) =>
              item.homeVisitId != _assessment.homeVisitId ||
              item.status == 'submitted',
        )
        .toList();
  }

  void setStep(int step) {
    if (step == 2) ensureVitalDefaults();
    currentStep = step.clamp(0, 6);
    _notify();
  }

  void setLanguage(String value) {
    if (value != 'en' && value != 'ml') return;
    if (language == value) return;
    language = value;
    _notify();
  }

  void update(VisitAssessment Function(VisitAssessment value) transform) {
    final previousDraftKey = _draftKey;
    _assessment = transform(
      _assessment,
    ).copyWith(updatedAt: DateTime.now(), status: 'draft', isComplete: false);
    _rememberDraftKeysFor(_assessment, extraKeys: [previousDraftKey]);
    _hasUserChanges = true;
    syncState = AssessmentSyncState.idle;
    syncMessage = null;
    _scheduleLocalSave();
    _notify();
  }

  void updateVitals(VisitVitals Function(VisitVitals value) transform) {
    update(
      (value) => value.copyWith(
        vitals: transform(
          value.status == 'submitted'
              ? value.vitals
              : value.vitals.withBaselineDefaults(),
        ),
      ),
    );
  }

  void ensureVitalDefaults() {
    if (_assessment.status == 'submitted' ||
        !_assessment.vitals.hasMissingMeasurements) {
      return;
    }
    _assessment = _assessment.copyWith(
      vitals: _assessment.vitals.withBaselineDefaults(),
      updatedAt: DateTime.now(),
    );
    _scheduleLocalSave();
  }

  void addMedicine(AssessmentMedicine medicine) {
    update(
      (value) => value.copyWith(medicines: [...value.medicines, medicine]),
    );
  }

  void replaceMedicine(int index, AssessmentMedicine medicine) {
    final medicines = [..._assessment.medicines];
    medicines[index] = medicine;
    update((value) => value.copyWith(medicines: medicines));
  }

  void removeMedicine(int index) {
    final medicines = [..._assessment.medicines]..removeAt(index);
    update((value) => value.copyWith(medicines: medicines));
  }

  void copyMedicinesFromPrevious() {
    VisitAssessment? source;
    for (final item in previousAssessments) {
      if (item.medicines.isNotEmpty) {
        source = item;
        break;
      }
    }
    if (source == null) return;
    final selectedSource = source;
    update(
      (value) => value.copyWith(
        medicines: selectedSource.medicines
            .map(
              (item) => AssessmentMedicine(
                medicineId: item.medicineId,
                medicineName: item.medicineName,
                strength: item.strength,
                instructionSpecified: item.instructionSpecified,
                instructionUsage: item.instructionUsage,
                routes: {...item.routes},
                duration: item.duration,
                remarks: item.remarks,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> removeDeletedAssessment(VisitAssessment assessment) async {
    await _repository.removeAssessmentFromHistory(assessment);
    previousAssessments = previousAssessments
        .where((item) => !_isSameAssessment(item, assessment))
        .toList();
    _notify();
  }

  Future<void> refreshHistory() async {
    _setHistory(await _repository.getHistory(_assessment.patientId));
    _notify();
  }

  void updateFinding(
    String key,
    ExamFinding Function(ExamFinding value) transform,
  ) {
    final findings = {..._assessment.physicalExam};
    findings[key] = transform(findings[key] ?? const ExamFinding());
    update((value) => value.copyWith(physicalExam: findings));
  }

  void toggleVisitPlan(String value) {
    final selected = {..._assessment.carePlan.visitPlans};
    selected.contains(value) ? selected.remove(value) : selected.add(value);
    update(
      (item) =>
          item.copyWith(carePlan: item.carePlan.copyWith(visitPlans: selected)),
    );
  }

  void updateVisitPlanNote(String value, String note) {
    final trimmed = note.trim();
    final notes = {..._assessment.carePlan.visitPlanNotes};
    trimmed.isEmpty ? notes.remove(value) : notes[value] = trimmed;

    final selected = {..._assessment.carePlan.visitPlans};
    trimmed.isEmpty ? selected.remove(value) : selected.add(value);

    update(
      (item) => item.copyWith(
        carePlan: item.carePlan.copyWith(
          visitPlans: selected,
          visitPlanNotes: notes,
        ),
      ),
    );
  }

  void toggleService(String value) {
    final selected = {..._assessment.carePlan.services};
    selected.contains(value) ? selected.remove(value) : selected.add(value);
    update(
      (item) =>
          item.copyWith(carePlan: item.carePlan.copyWith(services: selected)),
    );
  }

  String? validateStep(int step) {
    switch (step) {
      case 0:
        if (_assessment.patientId.isEmpty) {
          return 'This assessment needs a linked patient.';
        }
        if (_assessment.regNo.trim().isEmpty) {
          return 'Register number is required.';
        }
        if (_assessment.timeFrom.isEmpty || _assessment.timeTo.isEmpty) {
          return 'Add the visit start and end time.';
        }
        if (_assessment.team.trim().isEmpty) {
          return 'Select or enter the visiting team.';
        }
        if (_assessment.nurseName.trim().isEmpty) {
          return 'Nurse name is required.';
        }
        return null;
      case 1:
        return null;
      case 2:
        ensureVitalDefaults();
        final vitals = _assessment.vitals;
        if (vitals.pulse == null ||
            vitals.bpSystolic == null ||
            vitals.bpDiastolic == null ||
            vitals.respiratoryRate == null ||
            vitals.temperature == null ||
            vitals.spo2 == null) {
          return 'Complete the core vital measurements.';
        }
        if (vitals.spo2! < 0 || vitals.spo2! > 100) {
          return 'SpO₂ must be between 0 and 100.';
        }
        return null;
      case 3:
        if (_assessment.medicines.any(
          (medicine) => medicine.medicineName.trim().isEmpty,
        )) {
          return 'Every medicine needs a name.';
        }
        return null;
      case 4:
        if (_assessment.nursingDiagnosis.trim().isEmpty) {
          return 'Add the nursing diagnosis before continuing.';
        }
        return null;
      case 5:
        if (_assessment.carePlan.visitPlans.isEmpty) {
          return 'Select at least one visit plan.';
        }
        if (_assessment.carePlan.services.isEmpty) {
          return 'Select at least one required service.';
        }
        return null;
      case 6:
        for (var step = 0; step < 6; step++) {
          final error = validateStep(step);
          if (error != null) return error;
        }
        if (_assessment.nurseName.trim().isEmpty) {
          return 'Nurse name is required.';
        }
        if (!_assessment.confirmed) {
          return 'Confirm that the assessment information is correct.';
        }
        return null;
      default:
        return null;
    }
  }

  Future<bool> saveDraft({bool silent = false}) async {
    if (_assessment.status == 'submitted' || _assessment.isComplete) {
      await _repository.clearLocalDraft(_draftKey);
      syncState = AssessmentSyncState.saved;
      syncMessage = silent ? syncMessage : 'Assessment already submitted';
      if (!silent) _notify();
      return true;
    }
    if (!hasDraftInProgress) {
      syncState = AssessmentSyncState.saved;
      syncMessage = silent ? syncMessage : 'Ready for new assessment';
      if (!silent) _notify();
      return true;
    }
    if (syncState == AssessmentSyncState.saving) return false;
    syncState = AssessmentSyncState.saving;
    if (!silent) syncMessage = 'Saving draft…';
    _notify();

    final localValue = _assessment.copyWith(updatedAt: DateTime.now());
    _assessment = localValue;
    _rememberDraftKeysFor(localValue);
    await _repository.saveLocalDraft(localValue);

    if (localValue.homeVisitId.trim().isEmpty) {
      syncState = AssessmentSyncState.saved;
      syncMessage = 'Draft saved on this device';
      _notify();
      return true;
    }

    try {
      final synced = await _repository.syncDraft(localValue);
      _assessment = synced;
      _rememberDraftKeysFor(synced);
      await _repository.saveLocalDraft(synced);
      syncState = AssessmentSyncState.saved;
      syncMessage = 'Draft saved';
      _notify();
      return true;
    } catch (_) {
      syncState = AssessmentSyncState.offline;
      syncMessage = 'Saved offline — sync will retry automatically';
      _notify();
      return false;
    }
  }

  Future<bool> submit() async {
    if (isSubmitting) return false;

    final validationError = validateStep(6);
    if (validationError != null) {
      syncState = AssessmentSyncState.error;
      syncMessage = validationError;
      _notify();
      return false;
    }

    isSubmitting = true;
    syncMessage = 'Submitting assessment…';
    _notify();
    final originalDraftKey = _draftKey;
    _rememberDraftKeysFor(_assessment, extraKeys: [originalDraftKey]);
    try {
      var value = _assessment;
      final shouldResetAfterSubmit = _createsHomeVisitOnSubmit;
      final previousHomeVisitId = value.homeVisitId.trim();
      final previousPatientDateKey =
          VisitAssessmentRepository.patientDateDraftKeyFor(value);

      final homeVisit = await _repository.ensureHomeVisitForAssessment(value);
      final homeVisitId = homeVisit.id;
      if (homeVisitId == null || homeVisitId.isEmpty) {
        throw StateError('Could not create a linked home visit.');
      }
      value = value.copyWith(
        homeVisitId: homeVisitId,
        visitDate: DateTime.tryParse(homeVisit.visitDate) ?? value.visitDate,
        visitMode: homeVisit.visitMode.trim().isNotEmpty
            ? homeVisit.visitMode
            : value.visitMode,
        team: homeVisit.team?.trim().isNotEmpty == true
            ? homeVisit.team!
            : value.team,
        patientAddress: homeVisit.address.trim().isNotEmpty
            ? homeVisit.address
            : value.patientAddress,
      );
      _assessment = value;
      _rememberDraftKeysFor(
        value,
        extraKeys: [
          originalDraftKey,
          previousHomeVisitId,
          previousPatientDateKey,
        ],
      );
      if (previousHomeVisitId != homeVisitId) {
        await _clearLocalDraftsFor(
          value,
          extraKeys: [
            originalDraftKey,
            previousHomeVisitId,
            previousPatientDateKey,
          ],
        );
      }

      if (value.id == null) {
        value = await _repository.syncDraft(value);
        _assessment = value;
        _rememberDraftKeysFor(value);
      }
      final submitted = await _repository.submit(
        value.copyWith(status: 'submitted', isComplete: true),
      );
      _autoSaveTimer?.cancel();
      _localSaveDebounce?.cancel();
      _hasUserChanges = false;
      await _clearLocalDraftsFor(submitted, extraKeys: [originalDraftKey]);
      await _repository.cacheAssessmentInHistory(submitted);
      final history = await _repository.getHistory(submitted.patientId);
      _setHistory(_mergeHistory(history, submitted));
      _assessment = shouldResetAfterSubmit ? _freshAssessment() : submitted;
      currentStep = 0;
      syncState = AssessmentSyncState.saved;
      syncMessage = 'Assessment submitted';
      isSubmitting = false;
      _notify();
      return true;
    } catch (_) {
      if (hasDraftInProgress) {
        await _repository.saveLocalDraft(_assessment);
        _rememberDraftKeysFor(_assessment);
        final currentDraftKey = _draftKey;
        if (_createsHomeVisitOnSubmit && currentDraftKey != originalDraftKey) {
          await _repository.saveLocalDraftForKey(originalDraftKey, _assessment);
          _draftKeysSeen.add(originalDraftKey);
        }
      }
      syncState = AssessmentSyncState.offline;
      syncMessage = 'Could not submit. The draft remains safely stored.';
      isSubmitting = false;
      _notify();
      return false;
    }
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    if (_assessment.status == 'submitted' || _assessment.isComplete) return;
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => saveDraft(silent: true),
    );
  }

  void _scheduleLocalSave() {
    if (!hasDraftInProgress) return;
    _localSaveDebounce?.cancel();
    _localSaveDebounce = Timer(const Duration(milliseconds: 650), () async {
      await _repository.saveLocalDraft(_assessment);
    });
  }

  List<VisitAssessment> _mergeHistory(
    List<VisitAssessment> history,
    VisitAssessment assessment,
  ) {
    final merged = [...history];
    final index = merged.indexWhere((item) {
      if (assessment.id != null && item.id == assessment.id) return true;
      return item.homeVisitId == assessment.homeVisitId;
    });
    if (index >= 0) {
      merged[index] = assessment;
    } else {
      merged.add(assessment);
    }
    return merged;
  }

  bool _isSameAssessment(VisitAssessment a, VisitAssessment b) {
    if (a.id != null && b.id != null && a.id == b.id) return true;
    if (a.homeVisitId.trim().isNotEmpty &&
        b.homeVisitId.trim().isNotEmpty &&
        a.homeVisitId == b.homeVisitId) {
      return true;
    }
    return a.patientId == b.patientId &&
        VisitAssessmentRepository.patientDateDraftKeyFor(a) ==
            VisitAssessmentRepository.patientDateDraftKeyFor(b);
  }

  bool _hasSubmittedMatch(
    VisitAssessment draft,
    List<VisitAssessment> history,
  ) {
    return history.any(
      (item) =>
          (item.status == 'submitted' || item.isComplete) &&
          _isSubmittedVersionOfDraft(item, draft),
    );
  }

  bool _isSubmittedVersionOfDraft(
    VisitAssessment submitted,
    VisitAssessment draft,
  ) {
    if (submitted.id != null && draft.id != null && submitted.id == draft.id) {
      return true;
    }
    final submittedHomeVisitId = submitted.homeVisitId.trim();
    final draftHomeVisitId = draft.homeVisitId.trim();
    if (submittedHomeVisitId.isNotEmpty && draftHomeVisitId.isNotEmpty) {
      return submittedHomeVisitId == draftHomeVisitId;
    }
    return submitted.patientId == draft.patientId &&
        VisitAssessmentRepository.patientDateDraftKeyFor(submitted) ==
            VisitAssessmentRepository.patientDateDraftKeyFor(draft);
  }

  void _rememberDraftKeysFor(
    VisitAssessment assessment, {
    Iterable<String> extraKeys = const [],
  }) {
    _draftKeysSeen.addAll(extraKeys.where((key) => key.trim().isNotEmpty));
    _draftKeysSeen.add(VisitAssessmentRepository.draftKeyFor(assessment));
    _draftKeysSeen.add(
      VisitAssessmentRepository.patientDateDraftKeyFor(assessment),
    );
    if (assessment.homeVisitId.trim().isNotEmpty) {
      _draftKeysSeen.add(assessment.homeVisitId);
    }
  }

  Future<void> _clearLocalDraftsFor(
    VisitAssessment assessment, {
    Iterable<String> extraKeys = const [],
  }) {
    return _repository.clearLocalDraftsForAssessment(
      assessment,
      extraKeys: {..._draftKeysSeen, ...extraKeys},
    );
  }

  static VisitAssessment _identitySeed(VisitAssessment value) {
    return VisitAssessment(
      homeVisitId: value.homeVisitId,
      patientId: value.patientId,
      patientName: value.patientName,
      patientAge: value.patientAge,
      patientAddress: value.patientAddress,
      regNo: value.regNo,
      visitDate: value.visitDate,
      team: value.team,
      visitMode: value.visitMode,
      visitType: value.visitType,
      nurseName: value.nurseName,
      nurseId: value.nurseId,
    );
  }

  VisitAssessment _freshAssessment() {
    final now = DateTime.now();
    return VisitAssessment(
      homeVisitId: _createsHomeVisitOnSubmit
          ? ''
          : _newAssessmentSeed.homeVisitId,
      patientId: _newAssessmentSeed.patientId,
      patientName: _newAssessmentSeed.patientName,
      patientAge: _newAssessmentSeed.patientAge,
      patientAddress: _newAssessmentSeed.patientAddress,
      regNo: _newAssessmentSeed.regNo,
      visitDate: DateTime(now.year, now.month, now.day),
      team: _newAssessmentSeed.team,
      visitMode: _newAssessmentSeed.visitMode,
      visitType: _newAssessmentSeed.visitType,
      nurseName: _newAssessmentSeed.nurseName,
      nurseId: _newAssessmentSeed.nurseId,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoSaveTimer?.cancel();
    _localSaveDebounce?.cancel();
    if (hasDraftInProgress) {
      _repository.saveLocalDraft(_assessment);
    }
    super.dispose();
  }
}
