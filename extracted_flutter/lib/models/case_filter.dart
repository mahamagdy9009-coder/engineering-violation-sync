class CaseFilter {
  CaseFilter({
    Set<int>? years,
    Set<int>? violationTypeIds,
    Set<int>? drainIds,
    Set<int>? observerIds,
    Set<int>? caseStatusIds,
    Set<int>? adminSeizureStatusIds,
    Set<int>? dissipationStatusIds,
    Set<int>? paymentStatusIds,
    this.dateFrom,
    this.dateTo,
  }) : years = years ?? <int>{},
       violationTypeIds = violationTypeIds ?? <int>{},
       drainIds = drainIds ?? <int>{},
       observerIds = observerIds ?? <int>{},
       caseStatusIds = caseStatusIds ?? <int>{},
       adminSeizureStatusIds = adminSeizureStatusIds ?? <int>{},
       dissipationStatusIds = dissipationStatusIds ?? <int>{},
       paymentStatusIds = paymentStatusIds ?? <int>{};

  final Set<int> years;
  final Set<int> violationTypeIds;
  final Set<int> drainIds;
  final Set<int> observerIds;
  final Set<int> caseStatusIds;
  final Set<int> adminSeizureStatusIds;
  final Set<int> dissipationStatusIds;
  final Set<int> paymentStatusIds;

  // ── فلتر فترة التاريخ ────────────────────────────────────────
  final DateTime? dateFrom;
  final DateTime? dateTo;

  CaseFilter copy() {
    return CaseFilter(
      years: {...years},
      violationTypeIds: {...violationTypeIds},
      drainIds: {...drainIds},
      observerIds: {...observerIds},
      caseStatusIds: {...caseStatusIds},
      adminSeizureStatusIds: {...adminSeizureStatusIds},
      dissipationStatusIds: {...dissipationStatusIds},
      paymentStatusIds: {...paymentStatusIds},
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  CaseFilter copyWith({
    Set<int>? years,
    Set<int>? violationTypeIds,
    Set<int>? drainIds,
    Set<int>? observerIds,
    Set<int>? caseStatusIds,
    Set<int>? adminSeizureStatusIds,
    Set<int>? dissipationStatusIds,
    Set<int>? paymentStatusIds,
    Object? dateFrom = _sentinel,
    Object? dateTo = _sentinel,
  }) {
    return CaseFilter(
      years: years ?? {...this.years},
      violationTypeIds: violationTypeIds ?? {...this.violationTypeIds},
      drainIds: drainIds ?? {...this.drainIds},
      observerIds: observerIds ?? {...this.observerIds},
      caseStatusIds: caseStatusIds ?? {...this.caseStatusIds},
      adminSeizureStatusIds:
          adminSeizureStatusIds ?? {...this.adminSeizureStatusIds},
      dissipationStatusIds:
          dissipationStatusIds ?? {...this.dissipationStatusIds},
      paymentStatusIds: paymentStatusIds ?? {...this.paymentStatusIds},
      dateFrom: dateFrom == _sentinel ? this.dateFrom : dateFrom as DateTime?,
      dateTo: dateTo == _sentinel ? this.dateTo : dateTo as DateTime?,
    );
  }

  static const Object _sentinel = Object();

  int get activeCount {
    int count = years.length +
        violationTypeIds.length +
        drainIds.length +
        observerIds.length +
        caseStatusIds.length +
        adminSeizureStatusIds.length +
        dissipationStatusIds.length +
        paymentStatusIds.length;
    if (dateFrom != null) count++;
    if (dateTo != null) count++;
    return count;
  }

  bool get isEmpty => activeCount == 0;

  void clear() {
    years.clear();
    violationTypeIds.clear();
    drainIds.clear();
    observerIds.clear();
    caseStatusIds.clear();
    adminSeizureStatusIds.clear();
    dissipationStatusIds.clear();
    paymentStatusIds.clear();
  }
}
