import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/common/app_text_field.dart';
import '../widgets/common/glass_container.dart';
import '../widgets/common/gradient_button.dart';
import '../widgets/login_background.dart';
import '../widgets/login_desktop_hero.dart';
import '../widgets/login_header.dart';
import '../widgets/protected_signin_strip.dart';
import '../widgets/secure_footer.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: 'carevora123');
  final _newFacilityNameController = TextEditingController();
  final _newFacilityAddressController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _ageController = TextEditingController(text: '75');
  final _educationYearsController = TextEditingController(text: '12');

  Uint8List? _avatarBytes;
  String? _avatarBase64;
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedRole = 'CAREGIVER';
  bool _isNewFacility = false;
  int? _selectedElderHomeId = 1;
  String? _selectedElderHomeName = 'Serene Valley Senior Living';

  List<Map<String, dynamic>> _elderHomes = [
    {'id': 1, 'name': 'Serene Valley Senior Living', 'code': 'SV-101'},
    {'id': 2, 'name': 'Golden Sunset Eldercare', 'code': 'GS-202'},
    {'id': 3, 'name': 'Lotus Care Senior Home', 'code': 'LOT-861'},
  ];

  bool _isLoading = false;
  bool _isSuccess = false;
  bool _hasSubmittedOnce = false;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _fetchElderHomes();
  }

  Future<void> _fetchElderHomes() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.backendBaseUrl}/api/elder-homes'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded['data'] as List?;
        if (list != null && list.isNotEmpty) {
          if (mounted) {
            setState(() {
              _elderHomes = list
                  .map((e) => {
                        'id': e['id'] as int,
                        'name': e['name'] as String,
                        'code': e['facilityCode'] as String? ?? '',
                      })
                  .toList();
              if (_elderHomes.isNotEmpty) {
                _selectedElderHomeId = _elderHomes.first['id'] as int;
                _selectedElderHomeName = _elderHomes.first['name'] as String;
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _newFacilityNameController.dispose();
    _newFacilityAddressController.dispose();
    _roomNumberController.dispose();
    _ageController.dispose();
    _educationYearsController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar([ImageSource source = ImageSource.gallery]) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _avatarBytes = bytes;
          _avatarBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      debugPrint('Error picking avatar image: $e');
    }
  }

  void _clearAvatar() {
    setState(() {
      _avatarBytes = null;
      _avatarBase64 = null;
    });
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Upload Profile Picture',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select a photo for your ${_selectedRole.toLowerCase()} profile',
                style: const TextStyle(fontSize: 12, color: AppColors.body),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.image, color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'Choose from Gallery / Files',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text('Select a JPG, PNG image', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.camera, color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'Take Photo with Camera',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text('Capture live portrait', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              if (_avatarBytes != null) ...[
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.riskHighBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.trash2, color: AppColors.riskHigh, size: 20),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.riskHigh,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _clearAvatar();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPickerSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _avatarBytes != null
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.lilac.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _showImageSourceModal,
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _avatarBytes == null
                        ? const LinearGradient(
                            colors: [AppColors.primarySoft, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: Border.all(
                      color: _avatarBytes != null ? AppColors.primary : AppColors.lilac,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _avatarBytes != null
                        ? Image.memory(
                            _avatarBytes!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            _selectedRole == 'DOCTOR'
                                ? LucideIcons.stethoscope
                                : (_selectedRole == 'ELDER' ? LucideIcons.user : LucideIcons.heartHandshake),
                            size: 28,
                            color: AppColors.primary,
                          ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _avatarBytes != null ? AppColors.riskLow : AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      _avatarBytes != null ? LucideIcons.check : LucideIcons.camera,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Profile Picture',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _avatarBytes != null
                            ? AppColors.riskLowBg
                            : AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _avatarBytes != null ? 'Uploaded' : 'Optional',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _avatarBytes != null
                              ? AppColors.riskLow
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _avatarBytes != null
                      ? 'Photo ready for registration'
                      : 'Upload photo for your ${_selectedRole.toLowerCase()} profile',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.body,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: _showImageSourceModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _avatarBytes != null ? LucideIcons.refreshCw : LucideIcons.uploadCloud,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _avatarBytes != null ? 'Change Photo' : 'Upload Photo',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_avatarBytes != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _clearAvatar,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.riskHighBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.riskHigh.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(LucideIcons.trash2, size: 12, color: AppColors.riskHigh),
                              SizedBox(width: 4),
                              Text(
                                'Remove',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.riskHigh,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    setState(() => _hasSubmittedOnce = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    int? elderHomeIdToAssign = _selectedElderHomeId;
    String assignedHomeName = _selectedElderHomeName ?? 'Facility';

    if ((_selectedRole == 'CAREGIVER' || _selectedRole == 'ELDER') && _isNewFacility) {
      try {
        final regHomeRes = await http
            .post(
              Uri.parse('${AppConfig.backendBaseUrl}/api/elder-homes/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'name': _newFacilityNameController.text.trim(),
                'address': _newFacilityAddressController.text.trim().isEmpty
                    ? 'Colombo, Sri Lanka'
                    : _newFacilityAddressController.text.trim(),
                'contactEmail': _emailController.text.trim(),
                'contactPhone': '+94 11 234 5678',
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (regHomeRes.statusCode == 200) {
          final decoded = jsonDecode(regHomeRes.body);
          final data = decoded['data'];
          if (data != null && data['id'] != null) {
            elderHomeIdToAssign = data['id'] as int;
            assignedHomeName = data['name'] as String;
          }
        }
      } catch (_) {}
    }

    try {
      final reqBody = <String, dynamic>{
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'password': _passwordController.text.trim(),
        'role': _selectedRole,
      };

      if (_avatarBase64 != null && _avatarBase64!.isNotEmpty) {
        reqBody['avatarUrl'] = _avatarBase64;
      }

      if (_selectedRole == 'CAREGIVER' || _selectedRole == 'ELDER') {
        reqBody['elderHomeId'] = elderHomeIdToAssign;
      }
      if (_selectedRole == 'ELDER') {
        reqBody['roomNumber'] = _roomNumberController.text.trim().isEmpty
            ? '101'
            : _roomNumberController.text.trim();
        final ageVal = int.tryParse(_ageController.text.trim());
        reqBody['age'] = ageVal ?? 75;
        final eduVal = int.tryParse(_educationYearsController.text.trim());
        reqBody['educationYears'] = eduVal ?? 12;
      }

      await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(reqBody),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _successMessage = _selectedRole == 'DOCTOR'
            ? 'Registered as Doctor with global clinical access across all elder homes.'
            : 'Registered as ${_selectedRole.toLowerCase()} assigned to $assignedHomeName.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoginBackground(
        child: SafeArea(
          child: ResponsiveBuilder(
            mobile: (context) => _buildMobileLayout(),
            tablet: (context) => _buildTabletLayout(),
            desktop: (context) => _buildDesktopLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Hero Story Block
              const Expanded(
                flex: 6,
                child: Padding(
                  padding: EdgeInsets.only(right: 60),
                  child: LoginDesktopHero(),
                ),
              ),

              // Right Frosted-Glass Card
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _buildGlassCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoginHeader(),
              const SizedBox(height: 24),
              _buildGlassCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoginHeader(),
              const SizedBox(height: 20),
              _buildGlassCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard() {
    return GlassContainer(
      borderRadius: 32,
      blur: 20,
      color: AppColors.glassWhite,
      borderColor: AppColors.glassBorder,
      borderWidth: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: _isSuccess ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      autovalidateMode: _hasSubmittedOnce
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Gradient Accent Line
          Center(
            child: Container(
              height: 3.5,
              width: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accentPink],
                ),
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header Row with Back Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.lilac.withValues(alpha: 0.8),
                  ),
                ),
                child: const Icon(
                  LucideIcons.userPlus,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Register User & Elder Home',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Care community onboarding',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.body,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  LucideIcons.arrowLeft,
                  color: AppColors.navy,
                  size: 20,
                ),
                tooltip: 'Back to Login',
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Role Selector
          const Text(
            'Select Account Role',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRolePill('CAREGIVER', 'Caregiver', LucideIcons.heartHandshake),
              const SizedBox(width: 8),
              _buildRolePill('ELDER', 'Elder', LucideIcons.user),
              const SizedBox(width: 8),
              _buildRolePill('DOCTOR', 'Doctor', LucideIcons.stethoscope),
            ],
          ),
          const SizedBox(height: 14),

          // Profile Picture Upload Section
          _buildAvatarPickerSection(),

          // Elder Home Section
          if (_selectedRole == 'CAREGIVER' || _selectedRole == 'ELDER') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lavenderBg.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lilac.withValues(alpha: 0.7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(LucideIcons.building2, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Assign Elder Home Facility',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => _isNewFacility = !_isNewFacility);
                        },
                        child: Text(
                          _isNewFacility ? 'Choose Existing' : '+ Register New Home',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (!_isNewFacility) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedElderHomeId,
                          isExpanded: true,
                          items: _elderHomes.map((home) {
                            return DropdownMenuItem<int>(
                              value: home['id'] as int,
                              child: Text(
                                '${home['name']} (${home['code']})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedElderHomeId = val;
                                final found = _elderHomes.firstWhere(
                                  (h) => h['id'] == val,
                                  orElse: () => {'name': ''},
                                );
                                _selectedElderHomeName = found['name'] as String;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedRole == 'CAREGIVER'
                          ? 'Caregiver will only be able to view residents belonging to this elder home.'
                          : 'Elder will belong to this facility with private individual tracking.',
                      style: const TextStyle(fontSize: 11, color: AppColors.body),
                    ),
                  ] else ...[
                    AppTextField(
                      controller: _newFacilityNameController,
                      label: 'New Elder Home Name',
                      hintText: 'e.g. Blossom Elder Sanctuary',
                      leadingIcon: LucideIcons.building,
                      validator: (v) => (_isNewFacility && (v == null || v.trim().isEmpty))
                          ? 'Please enter facility name.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _newFacilityAddressController,
                      label: 'Address / Location',
                      hintText: 'e.g. 50 Park Lane, Kandy',
                      leadingIcon: LucideIcons.mapPin,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_selectedRole == 'DOCTOR') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.shieldCheck, size: 18, color: Color(0xFF0D9488)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Doctor privileges grant global oversight across all registered elder homes and all users.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF115E59),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Full Name Input
          AppTextField(
            controller: _nameController,
            label: 'Full Name',
            hintText: _selectedRole == 'DOCTOR' ? 'Dr. Samantha Reed' : 'Full Name',
            leadingIcon: LucideIcons.user,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Please enter your name.' : null,
          ),
          const SizedBox(height: 12),

          // Work Email Input
          AppTextField(
            controller: _emailController,
            label: 'Email Address',
            hintText: 'user@carevora.com',
            leadingIcon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your email.';
              }
              final regex = RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
              );
              if (!regex.hasMatch(v.trim())) {
                return 'Enter a valid email.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Password Input
          AppTextField(
            controller: _passwordController,
            label: 'Password',
            hintText: 'Enter password',
            leadingIcon: LucideIcons.lock,
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: (v) =>
                (v == null || v.length < 6) ? 'Password must be at least 6 characters.' : null,
          ),
          const SizedBox(height: 12),

          if (_selectedRole == 'ELDER') ...[
            AppTextField(
              controller: _roomNumberController,
              label: 'Room Number (Optional)',
              hintText: 'e.g. 104',
              leadingIcon: LucideIcons.bed,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _ageController,
                    label: 'Age (Years)',
                    hintText: 'e.g. 75',
                    leadingIcon: LucideIcons.calendar,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (_selectedRole == 'ELDER') {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter age.';
                        }
                        final val = int.tryParse(v.trim());
                        if (val == null || val < 1 || val > 130) {
                          return 'Valid age: 1-130.';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    controller: _educationYearsController,
                    label: 'Education (Years)',
                    hintText: 'e.g. 12',
                    leadingIcon: LucideIcons.graduationCap,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (_selectedRole == 'ELDER') {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter years.';
                        }
                        final val = int.tryParse(v.trim());
                        if (val == null || val < 0 || val > 40) {
                          return 'Valid years: 0-40.';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),

          // Submit Button
          GradientButton(
            isLoading: _isLoading,
            loadingLabel: 'Registering...',
            onPressed: _handleRegister,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  LucideIcons.userCheck,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  'Complete Registration',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Protected Sign-in Strip
          const ProtectedSignInStrip(),
          const SizedBox(height: 16),

          // Back to Login Link
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text(
                  'Already registered? ',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.body,
                  ),
                ),
                InkWell(
                  onTap: () => context.go('/login'),
                  child: const Text(
                    'Return to Login',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Secure Footer
          const SecureFooter(),
        ],
      ),
    );
  }

  Widget _buildRolePill(String roleKey, String label, IconData icon) {
    final isSelected = _selectedRole == roleKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedRole = roleKey),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.navy,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Gradient Accent Line
        Center(
          child: Container(
            height: 3.5,
            width: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accentPink],
              ),
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Success Icon Circle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.riskLowBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.riskLow.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: const Icon(
            LucideIcons.checkCircle2,
            size: 38,
            color: AppColors.riskLow,
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Registration Successful!',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),

        Text(
          _successMessage ?? 'Account created successfully.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.body,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (_avatarBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.memory(
                    _avatarBytes!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email: ${_emailController.text.trim()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: $_selectedRole',
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryDeep),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        GradientButton(
          onPressed: () => context.go('/login'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                LucideIcons.logIn,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Back to Sign In',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        const SecureFooter(),
      ],
    );
  }
}
