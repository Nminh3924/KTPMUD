import 'package:bcrypt/bcrypt.dart';
void main() {
  final password = 'HTAM1234'; // Mật khẩu mặc định
  final hashed = BCrypt.hashpw(password, BCrypt.gensalt());
  print(hashed); // Dùng giá trị này để thay thế trong SQL
}