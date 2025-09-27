import 'auth_service.dart';
import 'database.dart';

class AccountService {

  static Map<String, dynamic> account = {};

  // batch fetch
  static Future<Map<String, dynamic>> fetchProfile() async {
    Map<String, dynamic> result =
        await supabase.from('profiles').select().single();
    account = result;
    return result;
  }

  // batch update
  static Future<void> updateProfile(final Map<String, dynamic> data,
      {final bool autofilled = false}) async {
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
