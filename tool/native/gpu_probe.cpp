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
