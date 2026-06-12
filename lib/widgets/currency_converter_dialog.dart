import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CurrencyConverterDialog extends StatefulWidget {
  const CurrencyConverterDialog({super.key});

  @override
  State<CurrencyConverterDialog> createState() => _CurrencyConverterDialogState();
}

class _CurrencyConverterDialogState extends State<CurrencyConverterDialog> {
  double _amount = 0;
  double _rate = 0; // سعر الصرف
  String _result = "";
  bool _sarToYer = true; // الاتجاه

  void _convert() {
    if (_rate == 0) return;
    double res;
    if (_sarToYer) {
      res = _amount * _rate; // سعودي ليمني (ضرب)
    } else {
      res = _amount / _rate; // يمني لسعودي (قسمة)
    }
    setState(() {
      _result = res.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.background, AppColors.lightGrey],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'تحويل عملات سريع',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary, shadows: const [Shadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))]),
                ),
                const SizedBox(height: 20),
                // بطاقة اختيار الاتجاه
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.darkGrey,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Text('من: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.black87)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<bool>(
                          dropdownColor: AppColors.lightGrey,
                          initialValue: _sarToYer,
                          decoration: InputDecoration(
        
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.greyShade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                            ),
                            filled: true,
                            fillColor: AppColors.white,
                          ),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('سعودي (SAR)', style: TextStyle(color: AppColors.black87))),
                            DropdownMenuItem(value: false, child: Text('يمني (YER)', style: TextStyle(color: AppColors.black87))),
                          ],
                          onChanged: (v) => setState(() => _sarToYer = v!),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // بطاقة المبلغ وسعر الصرف
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.darkGrey,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'المبلغ',
                          labelStyle: const TextStyle(color: AppColors.grey700),
                          prefixIcon: Icon(Icons.numbers, color: AppColors.grey700),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.greyShade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _amount = double.tryParse(v) ?? 0,
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'سعر الصرف اليوم',
                          labelStyle: const TextStyle(color: AppColors.grey700),
                          prefixIcon: Icon(Icons.currency_exchange, color: AppColors.grey700),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.greyShade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _rate = double.tryParse(v) ?? 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // عرض النتيجة
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _result.isEmpty ? AppColors.greyShade400 : AppColors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _result.isEmpty ? AppColors.greyShade400 : AppColors.green),
                  ),
                  child: Center(
                    child: Text(
                      _result.isEmpty ? '---' : 'النتيجة: $_result ${_sarToYer ? 'YER' : 'SAR'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _result.isEmpty ? AppColors.black87 : AppColors.green,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // الأزرار
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('إغلاق', style: TextStyle(color: AppColors.grey700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _convert,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 5,
                        ),
                        child: const Text('تحويل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}