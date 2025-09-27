import 'auth_service.dart';
import 'database.dart';

class AccountService {
  static Map<String, dynamic> account = {};

  // batch fetch
  static Future<Map<String, dynamic>> fetchProfile() async {
    String? uuid = (await supabase.auth.getUser()).user?.id;
    if (uuid != null) {
      final result = await supabase
          .from('profiles')
          .select()
          .eq('id', uuid)
          .single();

      account = result[0] as Map<String, dynamic>;
      return account; // Return the account directly
    }
    throw Exception('User ID is null'); // Handle the case where uuid is null
  }

  // batch update
  static Future<void> updateProfile(
    final Map<String, dynamic> data, {
    final bool autofilled = false,
  }) async {
    if (AuthService.authorized(anon: false)) {
      final Map<String, dynamic> result = await supabase
          .from('profiles')
          .update(data)
          .eq('id', supabase.auth.currentUser!.id)
          .select()
          .single();
      account = result;
    }
  }
}
