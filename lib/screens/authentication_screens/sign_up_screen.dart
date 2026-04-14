import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/models/auth_data.dart';
import 'package:sahifaty/models/user.dart';
import 'package:sahifaty/screens/welcome_screen/welcome_screen.dart';
import 'package:sahifaty/screens/widgets/custom_button.dart';
import '../../controllers/users_controller.dart';
import '../../core/constants/assets.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/size_config.dart';
import '../../providers/users_provider.dart';
import '../widgets/custom_text.dart';
import '../widgets/no_pop_scope.dart';
import 'login_screen.dart';
import 'widgets/custom_auth_footer.dart';
import 'widgets/custom_auth_textfield.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late UsersController _userController;

  @override
  void dispose() {
    _userController.signUpConfirmedPasswordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _userController = UsersController();
  }

  @override
  Widget build(BuildContext context) {
    UsersProvider usersProvider = Provider.of<UsersProvider>(context);
    final Size size = MediaQuery.of(context).size;
    return NoPopScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        body: SingleChildScrollView(
          child: SizedBox(
            height: size.height,
            width: size.width,
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: SizeConfig.getProportionalWidth(25),
                        vertical: SizeConfig.getProportionalWidth(45)),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SizeConfig.customSizedBox(
                              1.5,
                              3.5,
                              Image.asset(
                                Assets.logo,
                                width: 100,
                                height: 100,
                              )),
                          SizeConfig.customSizedBox(null, 100, null),
                          Padding(
                              padding: EdgeInsets.only(
                                  top: SizeConfig.getProportionalHeight(10),
                                  bottom: SizeConfig.getProportionalHeight(13)),
                              child: CustomText(
                                text: "create_account".tr,
                                fontSize: 24,
                                fontWeight: FontWeight.normal,
                                color: AppColors.blackFontColor,
                                withBackground: false,
                              )),
                          CustomAuthenticationTextField(
                            hintText: 'enter_email_hint'.tr,
                            obscureText: false,
                            textEditingController:
                                _userController.signUpEmailController,
                            borderColor:
                                _userController.signUpEmailTextFieldBorderColor,
                          ),
                          SizeConfig.customSizedBox(null, 50, null),
                          CustomAuthenticationTextField(
                            hintText: 'username_hint'.tr,
                            obscureText: false,
                            textEditingController:
                                _userController.signUpUsernameController,
                            borderColor:
                                _userController.signUpEmailTextFieldBorderColor,
                          ),
                          SizeConfig.customSizedBox(null, 50, null),
                          CustomAuthenticationTextField(
                            hintText: 'password_hint'.tr,
                            obscureText: true,
                            textEditingController:
                                _userController.signUpPasswordController,
                            borderColor: _userController
                                .signUpPasswordTextFieldBorderColor,
                          ),
                          SizeConfig.customSizedBox(null, 50, null),
                          CustomAuthenticationTextField(
                            hintText: 'confirm_password_hint'.tr,
                            obscureText: true,
                            textEditingController: _userController
                                .signUpConfirmedPasswordController,
                            borderColor: _userController
                                .confirmPasswordTextFieldBorderColor,
                          ),
                          SizeConfig.customSizedBox(null, 20, null),
                          CustomButton(
                            onPressed: () async {
                              try {
                                _userController.checkEmptyFields(false);
                                // ✅ Check for empty fields
                                if (!_userController.noneIsEmpty) {
                                  setState(() {
                                    _userController
                                        .changeTextFieldsColors(false);
                                  });
                                  throw Exception("all_fields_required".tr);
                                }
                                // ✅ Validate email format
                                if (!_userController.isEmailValid(
                                  _userController.signUpEmailController.text
                                      .trim(),
                                )) {
                                  setState(() {
                                    _userController
                                            .signUpEmailTextFieldBorderColor =
                                        AppColors.errorColor;
                                  });
                                  throw Exception("invalid_email".tr);
                                }
                                // ✅ Check password validity
                                _userController.checkValidPassword();
                                if (!_userController.passwordIsValid) {
                                  setState(() {
                                    _userController
                                        .changeTextFieldsColors(false);
                                  });
                                  throw Exception("invalid_password".tr);
                                }
                                // ✅ Check password match
                                _userController.checkMatchedPassword();
                                if (!_userController.isMatched) {
                                  setState(() {
                                    _userController
                                        .changeTextFieldsColors(false);
                                  });
                                  throw Exception("passwords_no_match".tr);
                                }

                                // ✅ If all good → register user
                                AuthData authData =
                                    await UsersProvider().register(
                                  _userController.signUpUsernameController.text
                                      .trim(),
                                  _userController.signUpEmailController.text
                                      .trim(),
                                  _userController.signUpPasswordController.text,
                                );

                                if (!mounted) return;

                                setState(() {
                                  _userController.changeTextFieldsColors(false);
                                });

                                UsersController().clearTextFields();

                                User user = User(
                                    id: authData.user!.id,
                                    fullName: authData.user!.fullName,
                                    email: authData.user!.email);
                                usersProvider.setSelectedUser(user);

                                await usersProvider.saveUserSession(
                                    user, authData.accessToken!);

                                if (!mounted) return;

                                Get.to(() => const WelcomeScreen());
                              } catch (e) {
                                // ✅ All validation & register errors handled here
                                String message;

                                if (e
                                    .toString()
                                    .contains("email already in use")) {
                                  message = "email_taken".tr;
                                } else {
                                  message = e
                                      .toString()
                                      .replaceFirst('Exception: ', '');
                                }

                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      message,
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                );
                              }
                            },
                            width: SizeConfig.getProportionalWidth(150),
                            height: SizeConfig.getProportionalHeight(50),
                            text: "create_account".tr,
                          ),
                          SizeConfig.customSizedBox(null, 20, null),
                          CustomAuthFooter(
                            headingText: "already_have_account".tr,
                            tailText: "login_action".tr,
                            onTap: () {
                              UsersProvider().resetSignUpErrorText();
                              Get.to(() => const LoginScreen(
                                    firstScreen: false,
                                  ));
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                if (usersProvider.isLoading)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(),
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
