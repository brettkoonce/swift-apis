#ifndef X10_XLA_CLIENT_MESH_SERVICE_H_
#define X10_XLA_CLIENT_MESH_SERVICE_H_

#include <memory>
#include <string>
#include <vector>

#include "tensorflow/compiler/xla/xla_client/mesh_service.pb.h"
#include "tensorflow/compiler/xla/types.h"

namespace xla {
namespace service {

class MeshService {
  struct Impl;

 public:
  MeshService(const std::string& address, grpc::Config config);

  ~MeshService();

 private:
  std::unique_ptr<Impl> impl_;
};

class MeshClient {
  struct Impl;

 public:
  static MeshClient* Get();

  const std::string& address() const;

  grpc::Config GetConfig() const;

  std::vector<std::string> Rendezvous(int ordinal, const std::string& tag,
                                      const std::string& payload) const;

 private:
  explicit MeshClient(const std::string& address);

  ~MeshClient();

  std::unique_ptr<Impl> impl_;
};

}  // namespace service
}  // namespace xla

#endif  // X10_XLA_CLIENT_MESH_SERVICE_H_
