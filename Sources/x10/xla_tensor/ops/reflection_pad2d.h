#pragma once

#include <vector>

#include "tensorflow/compiler/tf2xla/xla_tensor/ir.h"

namespace swift_xla {
namespace ir {
namespace ops {

class ReflectionPad2d : public Node {
 public:
  ReflectionPad2d(const Value& input, std::vector<xla::int64> padding);

  NodePtr Clone(OpList operands) const override;

  XlaOpVector Lower(LoweringContext* loctx) const override;

  std::string ToString() const override;

  const std::vector<xla::int64>& padding() const { return padding_; }

 private:
  std::vector<xla::int64> padding_;
};

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
