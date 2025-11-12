import 'package:flutter/material.dart';

class ModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final int? change;
  final VoidCallback? onTap;

  const ModernStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.change,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = change != null && change! >= 0;

    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              splashColor: color.withOpacity(0.1),
              highlightColor: color.withOpacity(0.05),
              child: Container(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Icon with gradient background
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                color,
                                color.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),

                        // Change indicator
                        if (change != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isPositive
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 14,
                                  color: isPositive ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${isPositive ? '+' : ''}$change%',
                                  style: TextStyle(
                                    color: isPositive ? Colors.green : Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Title
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Value
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),

                    // Subtitle
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
