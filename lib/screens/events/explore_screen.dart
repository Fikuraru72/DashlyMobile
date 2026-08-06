import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/event_list_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../theme/dashly_theme.dart';
import 'event_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  EventStatus? _selectedFilter; // null means 'All'

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EventListProvider>();
      provider.loadExploreEvents();
      provider.loadMyEventsForMerge();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<EventListProvider>();
      if (!provider.isLoadingMore && provider.hasMore) {
        provider.loadMoreExploreEvents();
      }
    }
  }

  List<Event> _filterEvents(List<Event> events) {
    return events.where((e) {
      // Status filter
      if (_selectedFilter != null && e.status != _selectedFilter) return false;
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return e.name.toLowerCase().contains(query) ||
               e.description.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  void _openQRScannerSheet(BuildContext mainContext) {
    final MobileScannerController scannerController = MobileScannerController();
    bool isProcessingScan = false;

    showModalBottomSheet(
      context: mainContext,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(mainContext).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "SCAN EVENT QR CODE",
                    style: TextStyle(
                      color: mainContext.dashlyColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: mainContext.dashlyColors.textHint),
                    onPressed: () {
                      scannerController.dispose();
                      Navigator.pop(bottomSheetContext);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Point your camera at an event QR code to join instantly.",
                style: TextStyle(color: mainContext.dashlyColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: scannerController,
                        onDetect: (capture) async {
                          if (isProcessingScan) return;
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            final String? rawValue = barcode.rawValue;
                            if (rawValue != null && rawValue.isNotEmpty) {
                              isProcessingScan = true;
                              scannerController.stop();

                              // Show loading indicator
                              ScaffoldMessenger.of(mainContext).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                      SizedBox(width: 12),
                                      Text("Processing QR Code..."),
                                    ],
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              // Join event via token
                              final token = rawValue.trim();
                              final eventProv = mainContext.read<EventProvider>();
                              final result = await eventProv.joinEventViaToken(token);

                              if (!mainContext.mounted) return;
                              Navigator.pop(bottomSheetContext);

                              if (result != null && result['success'] == true) {
                                final eventListProv = mainContext.read<EventListProvider>();
                                await eventListProv.loadExploreEvents();
                                await eventListProv.loadMyEventsForMerge();

                                final eventIdInt = int.tryParse(result['eventId']?.toString() ?? '') ?? 0;
                                final joinedEvent = eventListProv.getEventWithParticipantData(eventIdInt);

                                if (joinedEvent != null) {
                                  Navigator.push(
                                    mainContext,
                                    MaterialPageRoute(
                                      builder: (_) => EventDetailScreen(event: joinedEvent),
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(mainContext).showSnackBar(
                                  SnackBar(
                                    content: Text(eventProv.errorMessage ?? 'Invalid QR Code or failed to join event'),
                                    backgroundColor: mainContext.dashlyColors.error,
                                  ),
                                );
                              }
                              break;
                            }
                          }
                        },
                      ),
                      // QR Target Reticle Overlay
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: mainContext.dashlyColors.accent, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventListProvider>();
    final allEvents = provider.exploreEvents;
    final filteredEvents = _filterEvents(allEvents);

    return Scaffold(
      appBar: AppBar(
        title: const Text("EXPLORE RACES", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: context.dashlyColors.accent, size: 26),
            tooltip: "Scan Event QR Code",
            onPressed: () => _openQRScannerSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(color: context.dashlyColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search events...',
                hintStyle: TextStyle(color: context.dashlyColors.textHint),
                prefixIcon: Icon(Icons.search_rounded, color: context.dashlyColors.textHint),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: context.dashlyColors.textHint, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.dashlyColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.dashlyColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.dashlyColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.dashlyColors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip(context, "All", null),
                const SizedBox(width: 8),
                _buildFilterChip(context, "Live", EventStatus.start),
                const SizedBox(width: 8),
                _buildFilterChip(context, "Upcoming", EventStatus.idle),
                const SizedBox(width: 8),
                _buildFilterChip(context, "Finished", EventStatus.finished),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Event List
          Expanded(
            child: provider.isLoadingExplore && allEvents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      final prov = context.read<EventListProvider>();
                      await prov.loadExploreEvents();
                      await prov.loadMyEventsForMerge();
                    },
                    child: filteredEvents.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 64, color: context.dashlyColors.textHint.withValues(alpha: 0.3)),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty ? "No events match \"$_searchQuery\"" : "No events available.",
                                      style: TextStyle(color: context.dashlyColors.textHint, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filteredEvents.length + (provider.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filteredEvents.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              }
                              return _buildEventCard(context, filteredEvents[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, EventStatus? status) {
    final isSelected = _selectedFilter == status;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.dashlyColors.accent : context.dashlyColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? context.dashlyColors.accent : context.dashlyColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : context.dashlyColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: context.dashlyColors.surface,
          borderRadius: DashlyTheme.radiusMd,
          border: Border.all(color: context.dashlyColors.divider, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: DashlyTheme.radiusMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image with status badge
              Stack(
                children: [
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.dashlyColors.surfaceLight, context.dashlyColors.surface],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: _buildBannerImage(context, event.bannerBase64),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildStatusBadge(context, event.status),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.dashlyColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: context.dashlyColors.textHint),
                        const SizedBox(width: 6),
                        Text(
                          "${event.dateEvent.day}/${event.dateEvent.month}/${event.dateEvent.year}",
                          style: TextStyle(color: context.dashlyColors.textHint, fontSize: 13),
                        ),
                        const Spacer(),
                        Icon(Icons.people_alt_rounded, size: 14, color: context.dashlyColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          "${event.currentCount} / ${event.maxParticipants}",
                          style: TextStyle(color: context.dashlyColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, EventStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case EventStatus.start:
        bg = context.dashlyColors.accent;
        fg = Colors.black;
        label = "LIVE NOW";
        break;
      case EventStatus.idle:
        bg = context.dashlyColors.surfaceLight;
        fg = context.dashlyColors.textSecondary;
        label = "UPCOMING";
        break;
      case EventStatus.finished:
        bg = Colors.black45;
        fg = context.dashlyColors.textHint;
        label = "FINISHED";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }

  Widget _buildBannerImage(BuildContext context, String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return Icon(Icons.map_rounded, color: context.dashlyColors.textHint.withOpacity(0.2), size: 64);
    }
    try {
      final cleanBase64 = base64String.split(',').last.replaceAll(RegExp(r'\s+'), '');
      final bytes = const Base64Decoder().convert(cleanBase64);
      return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } catch (e) {
      return Icon(Icons.broken_image_rounded, color: context.dashlyColors.error.withOpacity(0.5), size: 64);
    }
  }
}
