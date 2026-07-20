import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReviewListScreen extends StatefulWidget {
  final int userId;

  const ReviewListScreen({super.key, required this.userId});

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  List<dynamic> reviews = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  void _loadReviews() async {
    var result = await ApiService.getUserReviews(widget.userId);
    if (mounted) {
      setState(() {
        isLoading = false;
        if (result['status'] == 'success') {
          reviews = result['data'] ?? [];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'REVIEWS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : reviews.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada ulasan.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return _buildReviewCard(review);
                  },
                ),
    );
  }

  Widget _buildReviewCard(dynamic review) {
    int rating = review['rating'] ?? 0;
    
    // Potong string waktu agar lebih rapi (opsional)
    String dateStr = review['created_at'] != null 
        ? review['created_at'].toString().split('T')[0] 
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review['reviewer_name'] ?? 'Anonim',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            review['review_text'] ?? 'Tidak ada teks ulasan.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}