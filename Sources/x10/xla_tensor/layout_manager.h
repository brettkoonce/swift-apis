#pragma once

#include "absl/types/span.h"
#include "tensorflow/compiler/tf2xla/xla_tensor/device.h"
#include "tensorflow/compiler/xla/shape.h"
#include "tensorflow/compiler/xla/types.h"

namespace swift_xla {

// Creates a minor-to-major layout from given dimensions. The dynamic_dimensions
// slice should be either empty, or of the same size as dimensions.
xla::Shape MakeSwiftTensorLayout(absl::Span<const xla::int64> dimensions,
                                 absl::Span<const bool> dynamic_dimensions,
                                 xla::PrimitiveType type);

// Create an XLA shape with the given dimensions and type, suitable to be used
// in the specified device type. The type of device can affect the choice of the
// XLA layout. The dynamic_dimensions slice should be either empty, or of the
// same size as dimensions.
xla::Shape MakeArrayShapeFromDimensions(
    absl::Span<const xla::int64> dimensions,
    absl::Span<const bool> dynamic_dimensions, xla::PrimitiveType type,
    DeviceType device_type);

}  // namespace swift_xla
