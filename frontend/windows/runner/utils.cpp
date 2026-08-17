#include "utils.h"

#include <winsock2.h>
#include <ws2tcpip.h>

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <chrono>
#include <filesystem>
#include <iostream>
#include <string>
#include <thread>

#pragma comment(lib, "Ws2_32.lib")

namespace {

constexpr wchar_t kBackendHost[] = L"127.0.0.1";
constexpr unsigned short kBackendPort = 8000;
constexpr auto kBackendStartupTimeout = std::chrono::seconds(15);
constexpr auto kBackendPollInterval = std::chrono::milliseconds(150);

HANDLE g_backend_process = nullptr;
bool g_backend_started_by_runner = false;

struct BackendLaunchConfiguration {
  std::filesystem::path backend_root;
  std::filesystem::path python_directory;
  std::filesystem::path python_executable;
  std::filesystem::path server_script;
  std::filesystem::path working_directory;
  std::filesystem::path launch_log_path;
  bool packaged = true;
};

std::filesystem::path GetExecutableDirectory() {
  wchar_t buffer[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(nullptr, buffer, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return std::filesystem::current_path();
  }
  return std::filesystem::path(std::wstring(buffer, length)).parent_path();
}

std::filesystem::path GetBackendLogPath() {
  wchar_t* local_app_data = nullptr;
  size_t required_size = 0;
  if (_wdupenv_s(&local_app_data, &required_size, L"LOCALAPPDATA") != 0 ||
      local_app_data == nullptr) {
    return GetExecutableDirectory() / L"backend.log";
  }

  std::filesystem::path log_path =
      std::filesystem::path(local_app_data) / L"Risk management" / L"logs" /
      L"backend.log";
  free(local_app_data);
  return log_path;
}

std::filesystem::path GetBackendLaunchLogPath() {
  return GetBackendLogPath().parent_path() / L"backend-launch.log";
}

std::filesystem::path GetSourceBackendLaunchLogPath(
    const std::filesystem::path& source_backend_root) {
  return source_backend_root / L"data" / L"logs" / L"backend-launch.log";
}

std::filesystem::path FindSourceRepositoryRoot() {
  std::filesystem::path current = GetExecutableDirectory();
  std::error_code canonical_error;
  const std::filesystem::path canonical_current =
      std::filesystem::weakly_canonical(current, canonical_error);
  if (!canonical_error) {
    current = canonical_current;
  }

  for (int depth = 0; depth < 12; ++depth) {
    const std::filesystem::path backend_root = current / L"backend";
    if (std::filesystem::exists(backend_root / L"run_server.py") &&
        std::filesystem::exists(backend_root / L"app")) {
      return current;
    }

    const std::filesystem::path parent = current.parent_path();
    if (parent.empty() || parent == current) {
      break;
    }
    current = parent;
  }

  return std::filesystem::path();
}

BackendLaunchConfiguration GetPackagedBackendLaunchConfiguration() {
  const std::filesystem::path install_directory = GetExecutableDirectory();
  BackendLaunchConfiguration configuration;
  configuration.backend_root = install_directory / L"backend";
  configuration.python_directory = configuration.backend_root / L"python";
  configuration.python_executable =
      configuration.python_directory / L"python.exe";
  configuration.server_script =
      configuration.backend_root / L"src" / L"run_server.py";
  configuration.working_directory = configuration.python_directory;
  configuration.launch_log_path = GetBackendLaunchLogPath();
  configuration.packaged = true;
  return configuration;
}

bool TryGetSourceBackendLaunchConfiguration(
    BackendLaunchConfiguration* configuration) {
  const std::filesystem::path repository_root = FindSourceRepositoryRoot();
  if (repository_root.empty()) {
    return false;
  }

  BackendLaunchConfiguration source_configuration;
  source_configuration.backend_root = repository_root / L"backend";
  source_configuration.python_directory =
      source_configuration.backend_root / L".venv" / L"Scripts";
  source_configuration.python_executable =
      source_configuration.python_directory / L"python.exe";
  source_configuration.server_script =
      source_configuration.backend_root / L"run_server.py";
  source_configuration.working_directory = source_configuration.backend_root;
  source_configuration.launch_log_path =
      GetSourceBackendLaunchLogPath(source_configuration.backend_root);
  source_configuration.packaged = false;

  if (!std::filesystem::exists(source_configuration.python_executable) ||
      !std::filesystem::exists(source_configuration.server_script)) {
    return false;
  }

  if (configuration != nullptr) {
    *configuration = source_configuration;
  }
  return true;
}

bool IsBackendLaunchConfigurationAvailable(
    const BackendLaunchConfiguration& configuration) {
  return std::filesystem::exists(configuration.python_executable) &&
         std::filesystem::exists(configuration.server_script);
}

std::wstring BuildBackendResolutionErrorMessage(
    const BackendLaunchConfiguration& packaged_configuration) {
  std::wstring message =
      L"Runtime Python embarque introuvable: " +
      packaged_configuration.python_executable.wstring();

  const std::filesystem::path repository_root = FindSourceRepositoryRoot();
  if (repository_root.empty()) {
    message += L"\nBackend source introuvable depuis: " +
               GetExecutableDirectory().wstring();
    return message;
  }

  const std::filesystem::path source_backend_root =
      repository_root / L"backend";
  message += L"\nFallback developpement introuvable: " +
             (source_backend_root / L".venv" / L"Scripts" / L"python.exe")
                 .wstring();
  return message;
}

bool IsBackendReachable() {
  WSADATA wsa_data;
  if (::WSAStartup(MAKEWORD(2, 2), &wsa_data) != 0) {
    return false;
  }

  SOCKET socket_handle = ::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (socket_handle == INVALID_SOCKET) {
    ::WSACleanup();
    return false;
  }

  u_long non_blocking = 1;
  if (::ioctlsocket(socket_handle, FIONBIO, &non_blocking) != 0) {
    ::closesocket(socket_handle);
    ::WSACleanup();
    return false;
  }

  sockaddr_in address = {};
  address.sin_family = AF_INET;
  address.sin_port = htons(kBackendPort);
  if (::InetPtonW(AF_INET, kBackendHost, &address.sin_addr) != 1) {
    ::closesocket(socket_handle);
    ::WSACleanup();
    return false;
  }

  const int connect_result = ::connect(
      socket_handle, reinterpret_cast<sockaddr*>(&address), sizeof(address));
  if (connect_result == SOCKET_ERROR) {
    const int connect_error = ::WSAGetLastError();
    if (connect_error != WSAEWOULDBLOCK && connect_error != WSAEINPROGRESS &&
        connect_error != WSAEINVAL) {
      ::closesocket(socket_handle);
      ::WSACleanup();
      return false;
    }
  } else {
    ::closesocket(socket_handle);
    ::WSACleanup();
    return true;
  }

  fd_set write_set;
  FD_ZERO(&write_set);
  FD_SET(socket_handle, &write_set);

  timeval timeout = {};
  timeout.tv_sec = 0;
  timeout.tv_usec = 250 * 1000;

  const int select_result =
      ::select(0, nullptr, &write_set, nullptr, &timeout);
  if (select_result <= 0) {
    ::closesocket(socket_handle);
    ::WSACleanup();
    return false;
  }

  int socket_error = 0;
  int option_length = sizeof(socket_error);
  const int option_result =
      ::getsockopt(socket_handle, SOL_SOCKET, SO_ERROR,
                   reinterpret_cast<char*>(&socket_error), &option_length);

  ::closesocket(socket_handle);
  ::WSACleanup();
  return option_result == 0 && socket_error == 0;
}

std::wstring BuildBackendCommandLine(
    const std::filesystem::path& python_executable,
    const std::filesystem::path& server_script) {
  return L"\"" + python_executable.wstring() + L"\" \"" +
         server_script.wstring() + L"\"";
}

}  // namespace

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8 for the Engine to use.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument as it's the binary name.
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  unsigned int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      -1, nullptr, 0, nullptr, nullptr)
    -1; // remove the trailing null character
  int input_length = (int)wcslen(utf16_string);
  std::string utf8_string;
  if (target_length == 0 || target_length > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, utf8_string.data(), target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}

bool EnsureBackendServerRunning(std::wstring* error_message) {
  if (IsBackendReachable()) {
    return true;
  }

  BackendLaunchConfiguration configuration =
      GetPackagedBackendLaunchConfiguration();
  if (!IsBackendLaunchConfigurationAvailable(configuration)) {
    BackendLaunchConfiguration source_configuration;
    if (TryGetSourceBackendLaunchConfiguration(&source_configuration)) {
      configuration = source_configuration;
    }
  }

  if (!std::filesystem::exists(configuration.python_executable)) {
    if (error_message != nullptr) {
      *error_message = BuildBackendResolutionErrorMessage(configuration);
    }
    return false;
  }

  if (!std::filesystem::exists(configuration.server_script)) {
    if (error_message != nullptr) {
      *error_message =
          L"Lanceur backend introuvable: " +
          configuration.server_script.wstring();
    }
    return false;
  }

  if (configuration.packaged) {
    ::SetEnvironmentVariableW(L"RWA_PACKAGED", L"1");
  } else {
    ::SetEnvironmentVariableW(L"RWA_PACKAGED", nullptr);
  }
  ::SetEnvironmentVariableW(L"RWA_API_HOST", kBackendHost);
  ::SetEnvironmentVariableW(L"RWA_API_PORT", L"8000");
  // L'application de bureau parle a un backend lie a la boucle locale, sans
  // navigateur ni compte : elle n'a pas d'ecran de connexion et ne porte aucun
  // jeton. L'authentification, destinee au deploiement web, est donc
  // explicitement desactivee ici. Le backend refuse de demarrer avec
  // l'authentification active mais sans secret : ce drapeau evite ce blocage.
  ::SetEnvironmentVariableW(L"RWA_AUTH_ENABLED", L"0");
  ::SetEnvironmentVariableW(L"RWA_API_LOG_LEVEL", L"warning");
  ::SetEnvironmentVariableW(L"PYTHONUTF8", L"1");

  std::error_code create_directories_error;
  std::filesystem::create_directories(configuration.launch_log_path.parent_path(),
                                      create_directories_error);

  SECURITY_ATTRIBUTES security_attributes = {};
  security_attributes.nLength = sizeof(security_attributes);
  security_attributes.bInheritHandle = TRUE;
  security_attributes.lpSecurityDescriptor = nullptr;

  HANDLE log_handle = ::CreateFileW(
      configuration.launch_log_path.wstring().c_str(),
      FILE_APPEND_DATA,
      FILE_SHARE_READ | FILE_SHARE_WRITE,
      &security_attributes,
      OPEN_ALWAYS,
      FILE_ATTRIBUTE_NORMAL,
      nullptr);
  if (log_handle == INVALID_HANDLE_VALUE) {
    if (error_message != nullptr) {
      *error_message =
          L"Impossible d'ouvrir le journal backend: " +
          configuration.launch_log_path.wstring();
    }
    return false;
  }

  HANDLE null_handle = ::CreateFileW(
      L"NUL",
      GENERIC_READ | GENERIC_WRITE,
      FILE_SHARE_READ | FILE_SHARE_WRITE,
      &security_attributes,
      OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL,
      nullptr);
  if (null_handle == INVALID_HANDLE_VALUE) {
    ::CloseHandle(log_handle);
    if (error_message != nullptr) {
      *error_message =
          L"Impossible d'initialiser le canal standard du backend.";
    }
    return false;
  }

  std::wstring command_line =
      BuildBackendCommandLine(configuration.python_executable,
                              configuration.server_script);
  std::vector<wchar_t> mutable_command_line(command_line.begin(),
                                            command_line.end());
  mutable_command_line.push_back(L'\0');

  STARTUPINFOW startup_info = {};
  startup_info.cb = sizeof(startup_info);
  startup_info.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
  startup_info.wShowWindow = SW_HIDE;
  startup_info.hStdInput = null_handle;
  startup_info.hStdOutput = log_handle;
  startup_info.hStdError = log_handle;

  PROCESS_INFORMATION process_information = {};
  const std::wstring python_executable_string =
      configuration.python_executable.wstring();
  const std::wstring working_directory_string =
      configuration.working_directory.wstring();
  const BOOL create_result = ::CreateProcessW(
      python_executable_string.c_str(),
      mutable_command_line.data(),
      nullptr,
      nullptr,
      TRUE,
      CREATE_NO_WINDOW,
      nullptr,
      working_directory_string.c_str(),
      &startup_info,
      &process_information);

  ::CloseHandle(null_handle);
  ::CloseHandle(log_handle);

  if (!create_result) {
    if (error_message != nullptr) {
      *error_message =
          L"Impossible de demarrer le backend (code Win32 " +
          std::to_wstring(::GetLastError()) + L"). Consultez: " +
          configuration.launch_log_path.wstring();
    }
    return false;
  }

  ::CloseHandle(process_information.hThread);
  g_backend_process = process_information.hProcess;
  g_backend_started_by_runner = true;

  const auto deadline = std::chrono::steady_clock::now() + kBackendStartupTimeout;
  while (std::chrono::steady_clock::now() < deadline) {
    if (IsBackendReachable()) {
      return true;
    }

    DWORD wait_result = ::WaitForSingleObject(g_backend_process, 0);
    if (wait_result == WAIT_OBJECT_0) {
      DWORD exit_code = 0;
      ::GetExitCodeProcess(g_backend_process, &exit_code);
      if (error_message != nullptr) {
        *error_message =
            L"Le backend s'est arrete au demarrage (code " +
            std::to_wstring(exit_code) + L"). Consultez: " +
            configuration.launch_log_path.wstring();
      }
      StopManagedBackendServer();
      return false;
    }

    std::this_thread::sleep_for(kBackendPollInterval);
  }

  if (error_message != nullptr) {
    *error_message =
        L"Le backend ne repond pas sur 127.0.0.1:8000. Consultez: " +
        configuration.launch_log_path.wstring();
  }
  StopManagedBackendServer();
  return false;
}

void StopManagedBackendServer() {
  if (!g_backend_started_by_runner || g_backend_process == nullptr) {
    return;
  }

  DWORD exit_code = 0;
  if (::GetExitCodeProcess(g_backend_process, &exit_code) &&
      exit_code == STILL_ACTIVE) {
    ::TerminateProcess(g_backend_process, 0);
    ::WaitForSingleObject(g_backend_process, 2000);
  }

  ::CloseHandle(g_backend_process);
  g_backend_process = nullptr;
  g_backend_started_by_runner = false;
}
