import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'Atteni System Updates',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.rocket_launch,
                        size: 48,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Recent Updates Changelog',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.blueGrey.shade400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 32.0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildTimelineNode(
                  title: 'Flutter Native App Migration (v32.0.0)',
                  badgeText: 'Major Update',
                  badgeColor: Colors.purple,
                  items: [
                    'Native Mobile Experience: Completely migrated the web application to a high-performance Flutter native architecture.',
                    'Premium UI/UX: Integrated Apple-style glassmorphism, Bento-grid layouts, and smooth animations across all portals.',
                    'Offline Resiliency: The app now inherently handles connection drops with a beautiful offline overlay, preserving state.',
                    'Unified Assets: Seamlessly bundled existing images (logo.jpeg, etc.) directly into the native app bundle for zero-latency loading.',
                  ],
                  isFirst: true,
                ),
                _buildTimelineNode(
                  title: 'Performance, Stability & Security Updates',
                  badgeText: 'Hotfixes',
                  badgeColor: Colors.orange,
                  items: [
                    'Security (Issue #1): Moved hardcoded access codes to Firebase Realtime Database for enhanced security.',
                    'Performance (Issue #2 & #6): Replaced synchronous XHR with asynchronous Fetch API in role selection.',
                    'Bug Fixes (Issue #5 & #9): Fixed ReferenceError in student history by properly defining the grid variable.',
                    'Stats Accuracy (Issue #7): Updated Cloud Functions to correctly count \'Early\' (E) marks as Present.',
                    'UX Improvements (Issue #8): Replaced generic browser confirm() dialogs with premium modals.',
                  ],
                ),
                _buildTimelineNode(
                  title: 'Premium UI Overhaul & Bug Fixes',
                  badgeText: 'UI & Fixes',
                  badgeColor: Colors.teal,
                  items: [
                    'Premium Light Theme: Completely redesigned the Access Controls panel into a premium, glass-inspired light theme.',
                    'Node Provisioning Fix: Fixed the "Failed to create node" error by securely relocating the global registry.',
                    'Empty State Fallbacks: Fixed a bug where the Access Controls panel would render a completely blank screen if no nodes were active.',
                    'Master Kill Switch in Tables: Added a direct "Maintenance Mode" toggle inside the main School Nodes table.',
                  ],
                ),
                _buildTimelineNode(
                  title: 'Global Maintenance & Security Blockers',
                  badgeText: 'Security & Access',
                  badgeColor: Colors.red,
                  items: [
                    'App-Wide Maintenance Detection: Injected server-down detection scripts into all portals.',
                    'Instant Blackout Screen: If a specific school node is placed into maintenance mode, users face a blackout message.',
                    'Panel-Specific Toggles: Supermaster can selectively block login access to specific panels.',
                  ],
                ),
                _buildTimelineNode(
                  title: 'Multi-School Architecture Foundation',
                  badgeText: 'Core System Update',
                  badgeColor: Colors.blue,
                  items: [
                    'Dynamic Routing: The system no longer hardcodes paths. Parent and Teacher portals now dynamically fetch their database path.',
                    'Central Authentication Registry: Created a global registry to map user IDs to specific school databases dynamically.',
                    'Deprecation of Hardcoded Passwords: Old global passwords have been completely removed.',
                  ],
                  isLast: true,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode({
    required String title,
    required String badgeText,
    required MaterialColor badgeColor,
    required List<String> items,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Line and Dot
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // The line
                Positioned(
                  top: isFirst ? 20 : 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? 20 : null,
                  width: 2,
                  child: Container(color: Colors.blueGrey.shade300),
                ),
                // The dot
                Positioned(
                  top: 20,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Card Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0, top: 4.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueGrey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeColor.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 6.0,
                                right: 8.0,
                              ),
                              child: Icon(
                                Icons.circle,
                                size: 6,
                                color: Colors.blueGrey.shade400,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: Colors.blueGrey.shade600,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
