/// A page/sort/filter request for a data grid (§22, §30).
///
/// Pagination is always applied in the database layer (LIMIT/OFFSET); loading
/// the whole table into memory is forbidden.
class PageRequest {
  const PageRequest({
    this.page = 1,
    this.pageSize = 50,
    this.search = '',
    this.orderBy,
    this.ascending = true,
  });

  final int page;
  final int pageSize;
  final String search;

  /// Column name to order by; null = default ordering.
  final String? orderBy;
  final bool ascending;

  int get offset => (page - 1) * pageSize;

  PageRequest next() => PageRequest(
        page: page + 1,
        pageSize: pageSize,
        search: search,
        orderBy: orderBy,
        ascending: ascending,
      );

  PageRequest withSearch(String query) => PageRequest(
        page: 1,
        pageSize: pageSize,
        search: query,
        orderBy: orderBy,
        ascending: ascending,
      );

  @override
  String toString() =>
      'PageRequest(page: $page, size: $pageSize, search: "$search")';
}

/// One page of grid results plus the total row count.
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.total,
    required this.request,
  });

  final List<T> items;
  final int total;
  final PageRequest request;

  bool get hasMore => request.offset + items.length < total;

  int get pageCount =>
      total == 0 ? 0 : ((total + request.pageSize - 1) ~/ request.pageSize);
}