import 'package:flutter/material.dart';
import 'responsive.dart';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final approvals = const [
      _ApprovalCard(
        title: 'Laptop Purchase',
        subtitle: 'Requested by Admin',
        status: 'Pending',
      ),
      _ApprovalCard(
        title: 'Office Chairs',
        subtitle: 'Requested by Procurement',
        status: 'Approved',
      ),
      _ApprovalCard(
        title: 'Printer Ink',
        subtitle: 'Requested by Office Manager',
        status: 'Rejected',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        centerTitle: false,
      ),
      body: Responsive.centered(
        context,
        ListView.separated(
          padding: Responsive.pagePadding(context),
          itemCount: approvals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => approvals[index],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status) {
      case 'Approved':
        statusColor = const Color(0xFF2E7D32);
        break;
      case 'Rejected':
        statusColor = const Color(0xFFC62828);
        break;
      default:
        statusColor = const Color(0xFFEF6C00);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE7EAF6),
            child: const Icon(Icons.verified_user),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
