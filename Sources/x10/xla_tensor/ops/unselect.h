#pragma once

#include "tensorflow/compiler/tf2xla/xla_tensor/ir.h"

namespace swift_xla {
namespace ir {
namespace ops {

class Unselect : public Node {
 public:
  Unselect(const Value& target, const Value& source, xla::int64 dim,
           xla::int64 start, xla::int64 end, xla::int64 stride);

  NodePtr Clone(OpList operands) const override;

  XlaOpVector Lower(LoweringContext* loctx) const override;

  std::string ToString() const override;

  xla::int64 dim() const { return dim_; }

  xla::int64 start() const { return start_; }

  xla::int64 end() const { return end_; }

  xla::int64 stride() const { return stride_; }

 private:
  xla::int64 dim_;
  xla::int64 start_;
  xla::int64 end_;
  xla::int64 stride_;
};

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
