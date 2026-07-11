import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_mail_app/models/email.dart';
import 'package:cloud_mail_app/services/api_service.dart';
import 'package:cloud_mail_app/utils/storage.dart';

class AddUserScreen extends StatefulWidget {
  final CloudMailApi api;
  const AddUserScreen({super.key, required this.api});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _roleController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _handleAddUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = UserInfo(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
        roleName:
            _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
      );

      final response = await widget.api.addUser([user]);

      if (response.code == 200) {
        if (mounted) {
          showFunDialog(
            context,
            title: '添加成功！',
            message: '🎉 新用户已成功加入 Cloud Mail 大家庭！\n\n邮箱: ${user.email}',
            icon: Icons.person_add_alt_1,
            iconColor: Colors.green,
            actionText: '太棒了',
            onAction: () => Navigator.pop(context, true),
          );
        }
      } else {
        if (mounted) {
          showFunDialog(
            context,
            title: '添加失败',
            message: response.message.isEmpty
                ? '用户它害羞了，不肯注册...'
                : response.message,
            icon: Icons.error_outline,
            iconColor: Colors.orange,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showFunDialog(
          context,
          title: '出状况了',
          message: ErrorMessages.getErrorMessage(e),
          icon: Icons.cloud_off,
          iconColor: Colors.orange,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        title: Text(
          '添加用户',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildFormCard(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              size: 36,
              color: Color(0xFF6C63FF),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '创建新用户',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '给你的小伙伴也开个邮箱账号吧~',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField(
            label: '邮箱地址',
            hint: 'newuser@example.com',
            icon: Icons.email_outlined,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v!.isEmpty) return '邮箱可不能是空的哦~';
              if (!v.contains('@')) return '邮箱格式好像有点问题...';
              return null;
            },
          ),
          const SizedBox(height: 18),
          _buildField(
            label: '密码（可选）',
            hint: '不填将自动生成',
            icon: Icons.lock_outline,
            controller: _passwordController,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildField(
            label: '角色身份（可选）',
            hint: '不填使用默认角色',
            icon: Icons.shield_outlined,
            controller: _roleController,
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 22),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleAddUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                '创建用户',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}