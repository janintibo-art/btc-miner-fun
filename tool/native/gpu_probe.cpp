// Detection des cartes graphiques via OpenCL, sans dependance de compilation.
//
// Le SDK OpenCL n'est pas installe sur les machines de compilation, et il ne
// doit surtout pas etre requis pour lancer l'application : un ordinateur sans
// pilote compatible doit demarrer normalement. La bibliotheque est donc
// chargee a l'execution, et les quelques types dont nous avons besoin sont
// declares ici plutot qu'inclus.
//
// Cette premiere etape ne calcule rien : elle enumere le materiel. Si elle
// fonctionne, le chemin Dart -> FFI -> C++ -> pilote est prouve, et le noyau
// de hachage pourra suivre.

#include <windows.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

#include "gpu_kernel.cl.h"

namespace {

typedef int32_t cl_int;
typedef uint32_t cl_uint;
typedef uint64_t cl_ulong;
typedef uint64_t cl_bitfield;
typedef cl_bitfield cl_device_type;
typedef void* cl_platform_id;
typedef void* cl_device_id;

const cl_device_type kDeviceTypeAll = 0xFFFFFFFF;
const cl_uint kDeviceName = 0x102B;
const cl_uint kDeviceVendor = 0x102C;
const cl_uint kDeviceVersion = 0x102F;
const cl_uint kDeviceMaxComputeUnits = 0x1002;
const cl_uint kDeviceMaxClockFrequency = 0x100C;
const cl_uint kDeviceGlobalMemSize = 0x101F;
const cl_uint kDeviceTypeInfo = 0x1000;

typedef cl_int(__stdcall* PfnGetPlatformIDs)(cl_uint, cl_platform_id*, cl_uint*);
typedef cl_int(__stdcall* PfnGetDeviceIDs)(cl_platform_id, cl_device_type,
                                           cl_uint, cl_device_id*, cl_uint*);
typedef cl_int(__stdcall* PfnGetDeviceInfo)(cl_device_id, cl_uint, size_t,
                                            void*, size_t*);

struct OpenCl {
  HMODULE module = nullptr;
  PfnGetPlatformIDs GetPlatformIDs = nullptr;
  PfnGetDeviceIDs GetDeviceIDs = nullptr;
  PfnGetDeviceInfo GetDeviceInfo = nullptr;

  bool Load() {
    module = LoadLibraryA("OpenCL.dll");
    if (module == nullptr) return false;
    GetPlatformIDs =
        reinterpret_cast<PfnGetPlatformIDs>(GetProcAddress(module, "clGetPlatformIDs"));
    GetDeviceIDs =
        reinterpret_cast<PfnGetDeviceIDs>(GetProcAddress(module, "clGetDeviceIDs"));
    GetDeviceInfo =
        reinterpret_cast<PfnGetDeviceInfo>(GetProcAddress(module, "clGetDeviceInfo"));
    return GetPlatformIDs != nullptr && GetDeviceIDs != nullptr &&
           GetDeviceInfo != nullptr;
  }

  void Unload() {
    if (module != nullptr) FreeLibrary(module);
    module = nullptr;
  }
};

std::string TextInfo(const OpenCl& cl, cl_device_id device, cl_uint field) {
  size_t size = 0;
  if (cl.GetDeviceInfo(device, field, 0, nullptr, &size) != 0 || size == 0) {
    return std::string();
  }
  std::string value(size, '\0');
  if (cl.GetDeviceInfo(device, field, size, &value[0], nullptr) != 0) {
    return std::string();
  }
  while (!value.empty() && (value.back() == '\0' || value.back() == ' ')) {
    value.pop_back();
  }
  // Les separateurs du protocole ne doivent pas apparaitre dans un nom.
  for (char& c : value) {
    if (c == '|' || c == '\n' || c == '\r') c = ' ';
  }
  return value;
}

template <typename T>
T NumberInfo(const OpenCl& cl, cl_device_id device, cl_uint field) {
  T value = 0;
  if (cl.GetDeviceInfo(device, field, sizeof(T), &value, nullptr) != 0) {
    return 0;
  }
  return value;
}

}  // namespace

extern "C" {

// Remplit [out] avec une ligne par peripherique :
//   nom|fabricant|version|unites|frequenceMHz|memoireMio|type
// Retourne le nombre de peripheriques, ou un code negatif :
//   -1 OpenCL absent de la machine
//   -2 aucune plateforme OpenCL
//   -3 tampon trop petit
__declspec(dllexport) int32_t gpu_probe_list(char* out, int32_t capacity) {
  if (out == nullptr || capacity <= 0) return -3;
  out[0] = '\0';

  OpenCl cl;
  if (!cl.Load()) return -1;

  cl_uint platform_count = 0;
  if (cl.GetPlatformIDs(0, nullptr, &platform_count) != 0 || platform_count == 0) {
    cl.Unload();
    return -2;
  }
  if (platform_count > 8) platform_count = 8;

  cl_platform_id platforms[8];
  if (cl.GetPlatformIDs(platform_count, platforms, nullptr) != 0) {
    cl.Unload();
    return -2;
  }

  std::string result;
  int32_t total = 0;

  for (cl_uint p = 0; p < platform_count; ++p) {
    cl_uint device_count = 0;
    if (cl.GetDeviceIDs(platforms[p], kDeviceTypeAll, 0, nullptr, &device_count) != 0 ||
        device_count == 0) {
      continue;
    }
    if (device_count > 8) device_count = 8;

    cl_device_id devices[8];
    if (cl.GetDeviceIDs(platforms[p], kDeviceTypeAll, device_count, devices,
                        nullptr) != 0) {
      continue;
    }

    for (cl_uint d = 0; d < device_count; ++d) {
      const std::string name = TextInfo(cl, devices[d], kDeviceName);
      const std::string vendor = TextInfo(cl, devices[d], kDeviceVendor);
      const std::string version = TextInfo(cl, devices[d], kDeviceVersion);
      const cl_uint units =
          NumberInfo<cl_uint>(cl, devices[d], kDeviceMaxComputeUnits);
      const cl_uint clock =
          NumberInfo<cl_uint>(cl, devices[d], kDeviceMaxClockFrequency);
      const cl_ulong memory =
          NumberInfo<cl_ulong>(cl, devices[d], kDeviceGlobalMemSize);
      const cl_ulong type =
          NumberInfo<cl_ulong>(cl, devices[d], kDeviceTypeInfo);

      char line[1024];
      std::snprintf(line, sizeof(line), "%s|%s|%s|%u|%u|%llu|%llu\n",
                    name.c_str(), vendor.c_str(), version.c_str(), units, clock,
                    static_cast<unsigned long long>(memory / (1024 * 1024)),
                    static_cast<unsigned long long>(type));
      result += line;
      ++total;
    }
  }

  cl.Unload();

  if (static_cast<int32_t>(result.size()) + 1 > capacity) return -3;
  std::memcpy(out, result.c_str(), result.size() + 1);
  return total;
}

// Numero de version du pont natif, pour verifier que la DLL chargee est bien
// celle attendue.
__declspec(dllexport) int32_t gpu_probe_abi_version() { return 1; }

}  // extern "C"

// ===========================================================================
// Etape B : moteur de hachage OpenCL.
//
// Rien de ce qui sort d'ici n'est soumis a un pool avant que Dart n'ait
// verifie, hash par hash, que le GPU produit exactement le meme resultat que
// le processeur. La fonction gpu_miner_hash existe pour cela.
// ===========================================================================

namespace {

typedef void* cl_context;
typedef void* cl_command_queue;
typedef void* cl_program;
typedef void* cl_kernel;
typedef void* cl_mem;
typedef intptr_t cl_context_properties;
typedef cl_bitfield cl_mem_flags;
typedef cl_bitfield cl_command_queue_properties;
typedef cl_uint cl_program_build_info;

const cl_mem_flags kMemReadOnly = (1 << 2);
const cl_mem_flags kMemWriteOnly = (1 << 1);
const cl_mem_flags kMemReadWrite = (1 << 0);
const cl_mem_flags kMemCopyHostPtr = (1 << 5);
const cl_program_build_info kProgramBuildLog = 0x1183;

typedef cl_context(__stdcall* PfnCreateContext)(const cl_context_properties*,
                                                cl_uint, const cl_device_id*,
                                                void*, void*, cl_int*);
typedef cl_command_queue(__stdcall* PfnCreateCommandQueue)(
    cl_context, cl_device_id, cl_command_queue_properties, cl_int*);
typedef cl_program(__stdcall* PfnCreateProgramWithSource)(cl_context, cl_uint,
                                                          const char**,
                                                          const size_t*,
                                                          cl_int*);
typedef cl_int(__stdcall* PfnBuildProgram)(cl_program, cl_uint,
                                           const cl_device_id*, const char*,
                                           void*, void*);
typedef cl_int(__stdcall* PfnGetProgramBuildInfo)(cl_program, cl_device_id,
                                                  cl_program_build_info, size_t,
                                                  void*, size_t*);
typedef cl_kernel(__stdcall* PfnCreateKernel)(cl_program, const char*, cl_int*);
typedef cl_mem(__stdcall* PfnCreateBuffer)(cl_context, cl_mem_flags, size_t,
                                           void*, cl_int*);
typedef cl_int(__stdcall* PfnSetKernelArg)(cl_kernel, cl_uint, size_t,
                                           const void*);
typedef cl_int(__stdcall* PfnEnqueueNDRangeKernel)(cl_command_queue, cl_kernel,
                                                   cl_uint, const size_t*,
                                                   const size_t*, const size_t*,
                                                   cl_uint, const void*, void*);
typedef cl_int(__stdcall* PfnEnqueueWriteBuffer)(cl_command_queue, cl_mem,
                                                 cl_uint, size_t, size_t,
                                                 const void*, cl_uint,
                                                 const void*, void*);
typedef cl_int(__stdcall* PfnEnqueueReadBuffer)(cl_command_queue, cl_mem,
                                                cl_uint, size_t, size_t, void*,
                                                cl_uint, const void*, void*);
typedef cl_int(__stdcall* PfnFinish)(cl_command_queue);
typedef cl_int(__stdcall* PfnReleaseMemObject)(cl_mem);
typedef cl_int(__stdcall* PfnReleaseKernel)(cl_kernel);
typedef cl_int(__stdcall* PfnReleaseProgram)(cl_program);
typedef cl_int(__stdcall* PfnReleaseCommandQueue)(cl_command_queue);
typedef cl_int(__stdcall* PfnReleaseContext)(cl_context);

struct Miner {
  OpenCl cl;
  PfnCreateContext CreateContext = nullptr;
  PfnCreateCommandQueue CreateCommandQueue = nullptr;
  PfnCreateProgramWithSource CreateProgramWithSource = nullptr;
  PfnBuildProgram BuildProgram = nullptr;
  PfnGetProgramBuildInfo GetProgramBuildInfo = nullptr;
  PfnCreateKernel CreateKernel = nullptr;
  PfnCreateBuffer CreateBuffer = nullptr;
  PfnSetKernelArg SetKernelArg = nullptr;
  PfnEnqueueNDRangeKernel EnqueueNDRangeKernel = nullptr;
  PfnEnqueueWriteBuffer EnqueueWriteBuffer = nullptr;
  PfnEnqueueReadBuffer EnqueueReadBuffer = nullptr;
  PfnFinish Finish = nullptr;
  PfnReleaseMemObject ReleaseMemObject = nullptr;
  PfnReleaseKernel ReleaseKernel = nullptr;
  PfnReleaseProgram ReleaseProgram = nullptr;
  PfnReleaseCommandQueue ReleaseCommandQueue = nullptr;
  PfnReleaseContext ReleaseContext = nullptr;

  cl_device_id device = nullptr;
  cl_context context = nullptr;
  cl_command_queue queue = nullptr;
  cl_program program = nullptr;
  cl_kernel mine_kernel = nullptr;
  cl_kernel hash_kernel = nullptr;
  cl_mem header_buffer = nullptr;
  cl_mem output_buffer = nullptr;
  bool ready = false;

  template <typename T>
  bool Bind(T& target, const char* name) {
    target = reinterpret_cast<T>(GetProcAddress(cl.module, name));
    return target != nullptr;
  }

  bool BindAll() {
    return Bind(CreateContext, "clCreateContext") &&
           Bind(CreateCommandQueue, "clCreateCommandQueue") &&
           Bind(CreateProgramWithSource, "clCreateProgramWithSource") &&
           Bind(BuildProgram, "clBuildProgram") &&
           Bind(GetProgramBuildInfo, "clGetProgramBuildInfo") &&
           Bind(CreateKernel, "clCreateKernel") &&
           Bind(CreateBuffer, "clCreateBuffer") &&
           Bind(SetKernelArg, "clSetKernelArg") &&
           Bind(EnqueueNDRangeKernel, "clEnqueueNDRangeKernel") &&
           Bind(EnqueueWriteBuffer, "clEnqueueWriteBuffer") &&
           Bind(EnqueueReadBuffer, "clEnqueueReadBuffer") &&
           Bind(Finish, "clFinish") &&
           Bind(ReleaseMemObject, "clReleaseMemObject") &&
           Bind(ReleaseKernel, "clReleaseKernel") &&
           Bind(ReleaseProgram, "clReleaseProgram") &&
           Bind(ReleaseCommandQueue, "clReleaseCommandQueue") &&
           Bind(ReleaseContext, "clReleaseContext");
  }

  void Release() {
    if (header_buffer) ReleaseMemObject(header_buffer);
    if (output_buffer) ReleaseMemObject(output_buffer);
    if (mine_kernel) ReleaseKernel(mine_kernel);
    if (hash_kernel) ReleaseKernel(hash_kernel);
    if (program) ReleaseProgram(program);
    if (queue) ReleaseCommandQueue(queue);
    if (context) ReleaseContext(context);
    header_buffer = output_buffer = nullptr;
    mine_kernel = hash_kernel = nullptr;
    program = nullptr;
    queue = nullptr;
    context = nullptr;
    ready = false;
    cl.Unload();
  }
};

Miner g_miner;
const int32_t kMaxCandidates = 256;

void CopyMessage(char* out, int32_t capacity, const std::string& message) {
  if (out == nullptr || capacity <= 0) return;
  const size_t length = message.size() < static_cast<size_t>(capacity - 1)
                            ? message.size()
                            : static_cast<size_t>(capacity - 1);
  std::memcpy(out, message.c_str(), length);
  out[length] = '\0';
}

// Convertit les 80 octets de l'en-tete en 19 mots grand-boutistes. Le
// vingtieme, le nonce, est calcule dans le noyau.
void HeaderToWords(const uint8_t* header, uint32_t* words) {
  for (int i = 0; i < 19; ++i) {
    words[i] = (static_cast<uint32_t>(header[i * 4]) << 24) |
               (static_cast<uint32_t>(header[i * 4 + 1]) << 16) |
               (static_cast<uint32_t>(header[i * 4 + 2]) << 8) |
               static_cast<uint32_t>(header[i * 4 + 3]);
  }
}

}  // namespace

extern "C" {

// Prepare le peripherique choisi : contexte, file, compilation du noyau.
// Retourne 0 si tout est pret, un code negatif sinon. Le message d'erreur,
// journal de compilation compris, est recopie dans [error].
__declspec(dllexport) int32_t gpu_miner_init(int32_t device_index, char* error,
                                             int32_t error_capacity) {
  if (g_miner.ready) return 0;

  if (!g_miner.cl.Load()) {
    CopyMessage(error, error_capacity, "OpenCL.dll introuvable.");
    return -1;
  }
  if (!g_miner.BindAll()) {
    CopyMessage(error, error_capacity,
                "OpenCL present mais incomplet : fonctions manquantes.");
    g_miner.Release();
    return -2;
  }

  cl_uint platform_count = 0;
  cl_platform_id platforms[8];
  if (g_miner.cl.GetPlatformIDs(8, platforms, &platform_count) != 0 ||
      platform_count == 0) {
    CopyMessage(error, error_capacity, "Aucune plateforme OpenCL.");
    g_miner.Release();
    return -3;
  }

  int32_t seen = 0;
  for (cl_uint p = 0; p < platform_count && g_miner.device == nullptr; ++p) {
    cl_uint device_count = 0;
    cl_device_id devices[8];
    if (g_miner.cl.GetDeviceIDs(platforms[p], kDeviceTypeAll, 8, devices,
                                &device_count) != 0) {
      continue;
    }
    for (cl_uint d = 0; d < device_count; ++d) {
      if (seen == device_index) {
        g_miner.device = devices[d];
        break;
      }
      ++seen;
    }
  }
  if (g_miner.device == nullptr) {
    CopyMessage(error, error_capacity, "Peripherique demande introuvable.");
    g_miner.Release();
    return -4;
  }

  cl_int status = 0;
  g_miner.context = g_miner.CreateContext(nullptr, 1, &g_miner.device, nullptr,
                                          nullptr, &status);
  if (status != 0 || g_miner.context == nullptr) {
    CopyMessage(error, error_capacity, "Creation du contexte impossible.");
    g_miner.Release();
    return -5;
  }

  g_miner.queue =
      g_miner.CreateCommandQueue(g_miner.context, g_miner.device, 0, &status);
  if (status != 0 || g_miner.queue == nullptr) {
    CopyMessage(error, error_capacity, "Creation de la file impossible.");
    g_miner.Release();
    return -6;
  }

  const char* sources[1] = {kSha256Kernel};
  g_miner.program =
      g_miner.CreateProgramWithSource(g_miner.context, 1, sources, nullptr,
                                      &status);
  if (status != 0 || g_miner.program == nullptr) {
    CopyMessage(error, error_capacity, "Chargement du noyau impossible.");
    g_miner.Release();
    return -7;
  }

  status = g_miner.BuildProgram(g_miner.program, 1, &g_miner.device,
                                "-cl-std=CL1.2", nullptr, nullptr);
  if (status != 0) {
    // Le journal du compilateur est la seule information exploitable a
    // distance : il est remonte tel quel.
    std::string log(4096, '\0');
    size_t log_size = 0;
    g_miner.GetProgramBuildInfo(g_miner.program, g_miner.device,
                                kProgramBuildLog, log.size(), &log[0],
                                &log_size);
    log.resize(log_size > 0 ? log_size : 0);
    CopyMessage(error, error_capacity,
                "Compilation du noyau echouee : " + log);
    g_miner.Release();
    return -8;
  }

  g_miner.mine_kernel = g_miner.CreateKernel(g_miner.program, "mine", &status);
  if (status != 0) {
    CopyMessage(error, error_capacity, "Noyau 'mine' introuvable.");
    g_miner.Release();
    return -9;
  }
  g_miner.hash_kernel =
      g_miner.CreateKernel(g_miner.program, "hash_one", &status);
  if (status != 0) {
    CopyMessage(error, error_capacity, "Noyau 'hash_one' introuvable.");
    g_miner.Release();
    return -10;
  }

  g_miner.header_buffer = g_miner.CreateBuffer(
      g_miner.context, kMemReadOnly, sizeof(uint32_t) * 19, nullptr, &status);
  g_miner.output_buffer = g_miner.CreateBuffer(
      g_miner.context, kMemReadWrite, sizeof(uint32_t) * (kMaxCandidates + 1),
      nullptr, &status);
  if (status != 0 || g_miner.header_buffer == nullptr ||
      g_miner.output_buffer == nullptr) {
    CopyMessage(error, error_capacity, "Allocation memoire GPU impossible.");
    g_miner.Release();
    return -11;
  }

  g_miner.ready = true;
  CopyMessage(error, error_capacity, "Moteur GPU pret.");
  return 0;
}

// Hash complet d'un nonce unique : c'est la fonction d'auto-test.
__declspec(dllexport) int32_t gpu_miner_hash(const uint8_t* header,
                                             uint32_t nonce, uint8_t* out32) {
  if (!g_miner.ready) return -1;
  if (header == nullptr || out32 == nullptr) return -2;

  uint32_t words[19];
  HeaderToWords(header, words);

  if (g_miner.EnqueueWriteBuffer(g_miner.queue, g_miner.header_buffer, 1, 0,
                                 sizeof(words), words, 0, nullptr,
                                 nullptr) != 0) {
    return -3;
  }

  if (g_miner.SetKernelArg(g_miner.hash_kernel, 0, sizeof(cl_mem),
                           &g_miner.header_buffer) != 0 ||
      g_miner.SetKernelArg(g_miner.hash_kernel, 1, sizeof(uint32_t), &nonce) != 0 ||
      g_miner.SetKernelArg(g_miner.hash_kernel, 2, sizeof(cl_mem),
                           &g_miner.output_buffer) != 0) {
    return -4;
  }

  const size_t global_size = 1;
  if (g_miner.EnqueueNDRangeKernel(g_miner.queue, g_miner.hash_kernel, 1,
                                   nullptr, &global_size, nullptr, 0, nullptr,
                                   nullptr) != 0) {
    return -5;
  }
  g_miner.Finish(g_miner.queue);

  uint32_t digest[8] = {0};
  if (g_miner.EnqueueReadBuffer(g_miner.queue, g_miner.output_buffer, 1, 0,
                                sizeof(digest), digest, 0, nullptr,
                                nullptr) != 0) {
    return -6;
  }

  for (int i = 0; i < 8; ++i) {
    out32[i * 4] = static_cast<uint8_t>((digest[i] >> 24) & 0xff);
    out32[i * 4 + 1] = static_cast<uint8_t>((digest[i] >> 16) & 0xff);
    out32[i * 4 + 2] = static_cast<uint8_t>((digest[i] >> 8) & 0xff);
    out32[i * 4 + 3] = static_cast<uint8_t>(digest[i] & 0xff);
  }
  return 0;
}

// Balaye [count] nonces a partir de [base_nonce] et remonte les candidats.
// Retourne leur nombre, ou un code negatif.
__declspec(dllexport) int32_t gpu_miner_search(const uint8_t* header,
                                               uint32_t base_nonce,
                                               uint32_t count,
                                               uint32_t target_head,
                                               uint32_t* out_nonces,
                                               int32_t out_capacity) {
  if (!g_miner.ready) return -1;
  if (header == nullptr || out_nonces == nullptr || count == 0) return -2;

  uint32_t words[19];
  HeaderToWords(header, words);
  if (g_miner.EnqueueWriteBuffer(g_miner.queue, g_miner.header_buffer, 1, 0,
                                 sizeof(words), words, 0, nullptr,
                                 nullptr) != 0) {
    return -3;
  }

  uint32_t reset[1] = {0};
  if (g_miner.EnqueueWriteBuffer(g_miner.queue, g_miner.output_buffer, 1, 0,
                                 sizeof(reset), reset, 0, nullptr,
                                 nullptr) != 0) {
    return -4;
  }

  const uint32_t capacity = static_cast<uint32_t>(kMaxCandidates);
  if (g_miner.SetKernelArg(g_miner.mine_kernel, 0, sizeof(cl_mem),
                           &g_miner.header_buffer) != 0 ||
      g_miner.SetKernelArg(g_miner.mine_kernel, 1, sizeof(uint32_t),
                           &base_nonce) != 0 ||
      g_miner.SetKernelArg(g_miner.mine_kernel, 2, sizeof(uint32_t),
                           &target_head) != 0 ||
      g_miner.SetKernelArg(g_miner.mine_kernel, 3, sizeof(cl_mem),
                           &g_miner.output_buffer) != 0 ||
      g_miner.SetKernelArg(g_miner.mine_kernel, 4, sizeof(uint32_t),
                           &capacity) != 0) {
    return -5;
  }

  const size_t global_size = count;
  if (g_miner.EnqueueNDRangeKernel(g_miner.queue, g_miner.mine_kernel, 1,
                                   nullptr, &global_size, nullptr, 0, nullptr,
                                   nullptr) != 0) {
    return -6;
  }
  g_miner.Finish(g_miner.queue);

  uint32_t results[kMaxCandidates + 1] = {0};
  if (g_miner.EnqueueReadBuffer(g_miner.queue, g_miner.output_buffer, 1, 0,
                                sizeof(results), results, 0, nullptr,
                                nullptr) != 0) {
    return -7;
  }

  int32_t found = static_cast<int32_t>(results[0]);
  if (found > kMaxCandidates) found = kMaxCandidates;
  if (found > out_capacity) found = out_capacity;
  for (int32_t i = 0; i < found; ++i) out_nonces[i] = results[1 + i];
  return found;
}

__declspec(dllexport) void gpu_miner_shutdown() {
  if (g_miner.ready || g_miner.cl.module != nullptr) g_miner.Release();
}

}  // extern "C"
