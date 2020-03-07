#pragma once

#include "absl/types/span.h"
#include "tensorflow/compiler/tf2xla/xla_tensor/ir.h"

namespace swift_xla {
namespace ir {
namespace ops {

// IR node for a tensor view.
class View : public Node {
 public:
  View(const Value& input, std::vector<xla::int64> output_size);

  XlaOpVector Lower(LoweringContext* loctx) const override;

  std::string ToString() const override;

  const std::vector<xla::int64>& output_size() const { return output_size_; }

 private:
  // The possibly incomplete output size.
  std::vector<xla::int64> output_size_;
};

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
