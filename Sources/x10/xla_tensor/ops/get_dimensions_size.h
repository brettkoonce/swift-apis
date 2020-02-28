#pragma once

#include <vector>

#include "tensorflow/compiler/tf2xla/xla_tensor/ir.h"

namespace swift_xla {
namespace ir {
namespace ops {

class GetDimensionsSize : public Node {
 public:
  GetDimensionsSize(const Value& input, std::vector<xla::int64> dimensions);

  NodePtr Clone(OpList operands) const override;

  XlaOpVector Lower(LoweringContext* loctx) const override;

  std::string ToString() const override;

  const std::vector<xla::int64>& dimensions() const { return dimensions_; }

 private:
  std::vector<xla::int64> dimensions_;
};

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
