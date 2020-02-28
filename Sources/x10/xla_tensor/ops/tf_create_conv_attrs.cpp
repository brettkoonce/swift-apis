#include "tensorflow/compiler/tf2xla/xla_tensor/ops/tf_create_conv_attrs.h"

#include "tensorflow/compiler/tf2xla/xla_tensor/helpers.h"

namespace swift_xla {
namespace ir {
namespace ops {

tensorflow::ConvOpAttrs CreateConvOpAttrs(
    int num_spatial_dims, bool depthwise, absl::Span<const xla::int64> strides,
    tensorflow::Padding padding, absl::Span<const xla::int64> explicit_paddings,
    tensorflow::TensorFormat data_format,
    absl::Span<const xla::int64> dilations) {
  CHECK(padding == tensorflow::EXPLICIT || explicit_paddings.empty())
      << "Unexpected explicit padding";
  tensorflow::ConvOpAttrs attrs;
  attrs.depthwise = depthwise;
  attrs.num_spatial_dims = num_spatial_dims;
  attrs.dilations = xla::util::ToVector<xla::int32>(dilations);
  attrs.strides = xla::util::ToVector<xla::int32>(strides);
  attrs.padding = padding;
  attrs.explicit_paddings = XlaHelpers::I64List(explicit_paddings);
  attrs.data_format = data_format;
  return attrs;
}

}  // namespace ops
}  // namespace ir
}  // namespace swift_xla
