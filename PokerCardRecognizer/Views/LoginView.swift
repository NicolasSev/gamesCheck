import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Вход в приложение")
                .font(.title)
                .padding(.top, 40)

            TextField("Логин", text: $authViewModel.login)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            SecureField("Пароль", text: $authViewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            if let error = authViewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            // Стандартный вход через логин и пароль
            Button(action: {
                authViewModel.signIn()
            }) {
                Text("Войти")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Кнопка для входа через Face ID
            Button(action: {
                authViewModel.authenticateBiometrically()
            }) {
                Label("Войти с Face ID", systemImage: "faceid")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}
