class UserModel {
  final String id;
  final String nome;
  final String email;
  final String role; // Aqui está a chave: 'admin', 'barbeiro' ou 'cliente'

  UserModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.role,
  });

  // Método para converter o JSON da sua API em um objeto Dart
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'cliente', // Fallback de segurança para 'cliente'
    );
  }
}