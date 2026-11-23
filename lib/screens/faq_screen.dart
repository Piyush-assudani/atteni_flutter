import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'FAQ',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Top Left Light Blue Circle Decoration
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE0F2FE),
              ),
            ),
          ),
          // Middle Left Light Purple Circle
          Positioned(
            top: 350,
            left: -150,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF3E8FF),
              ),
            ),
          ),
          // Bottom Right Pink Circle
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFCE7F3),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Help Center & FAQ',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Everything you need to know about the Atteni real-time attendance system.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 48),

                  _FaqCard(
                    question: 'What is Atteni and how does it work?',
                    answer:
                        'Atteni is a real-time school attendance and tracking system. It allows teachers to mark attendance digitally and enables parents to track the live progress of their child\'s attendance through the Parent Portal.',
                    icon: Icons.school_rounded,
                    color: Colors.blue,
                  ),
                  _FaqCard(
                    question: 'How does the Gatekeeper Module function?',
                    answer: 'The Gatekeeper module provides enhanced security by verifying and logging every student\'s entry and exit at the school gates in real-time, ensuring campus safety and accurate records.',
                    icon: Icons.security_rounded,
                    color: Colors.red,
                  ),
                  _FaqCard(
                    question: 'What is the Task Manager for Admin & Staff?',
                    answer: 'The Task Manager is an internal workflow module where admins can assign, track, and manage daily responsibilities for the staff, ensuring smooth administrative operations.',
                    icon: Icons.assignment_turned_in_rounded,
                    color: Colors.amber,
                  ),
                  _FaqCard(
                    question: 'How do parents receive their Access Code?',
                    answer: 'Schools generate and securely distribute a unique Access Code to parents. Parents use this code to securely access their child\'s portal.',
                    icon: Icons.password_rounded,
                    color: Colors.teal,
                  ),
                  _FaqCard(
                    question: 'Is the Atteni app free for schools?',
                    answer:
                        'Atteni offers standard features and trial options for schools to evaluate our services. For complete deployments and advanced capabilities, we offer flexible premium pricing tiers tailored to the school\'s requirements. Contact us to learn more.',
                    icon: Icons.money_off_rounded,
                    color: Colors.green,
                  ),
                  _FaqCard(
                    question: 'Is my data secure on Atteni?',
                    answer:
                        'Absolutely. Atteni uses secure Firebase encryption to protect student and school data. We prioritize student privacy and ensure that only authorized parents and staff can access sensitive information.',
                    icon: Icons.shield_rounded,
                    color: Colors.purple,
                  ),
                  _FaqCard(
                    question: 'Who created Atteni?',
                    answer:
                        'Atteni was created by Piyush Assudani, a developer and entrepreneur from the Assudani Group. He is also the creator of PyPocket.xyz and other innovative tech solutions. Idea and Inspiration of Kalpesh Kumar Bhoi Sir.',
                    icon: Icons.person_rounded,
                    color: Colors.indigo,
                  ),

                  const SizedBox(height: 40),
                  Text(
                    'A PRODUCT OF ASSUDANI GROUP',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqCard extends StatefulWidget {
  final String question;
  final String answer;
  final IconData icon;
  final MaterialColor color;

  const _FaqCard({
    required this.question,
    required this.answer,
    required this.icon,
    required this.color,
  });

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isExpanded ? widget.color.shade200 : Colors.grey.shade100,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.color.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, color: widget.color.shade600, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.question,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Container(
                    height: _isExpanded ? null : 0,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, left: 52),
                      child: Text(
                        widget.answer,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
