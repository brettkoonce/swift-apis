#pragma once

#include "tensorflow/compiler/xla/xla_client/computation_client.h"
#include "tensorflow/compiler/tf2xla/xla_tensor/ir.h"

namespace swift_xla {
namespace ir {
namespace ops {

class DeviceData : public Node {
 public:
  DeviceData(std::shared_ptr<xla::ComputationClient::Data> data);

  std::string ToString() const override;

  NodePtr Clone(OpList operands) const override;

  XlaOpVector Lower(LoweringContext* loctx) const override;

  const std::shared_ptr<xla::ComputationClient::Data>& data() const {
    return data_;
  }

 private:
  std::shared_ptr<xla::ComputationClient::Data> data_;
};

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
