#include "source/common/json/json_loader.h"

#include "source/common/json/json_internal.h"
#include "source/common/runtime/runtime_features.h"

namespace Envoy {
namespace Json {

ObjectSharedPtr Factory::loadFromString(const std::string& json, bool ignore_comments) {
  return Nlohmann::Factory::loadFromString(json, ignore_comments);
}

absl::StatusOr<ObjectSharedPtr> Factory::loadFromStringNoThrow(const std::string& json,
                                                               bool ignore_comments) {
  return Nlohmann::Factory::loadFromStringNoThrow(json, ignore_comments);
}

ObjectSharedPtr Factory::loadFromProtobufStruct(const ProtobufWkt::Struct& protobuf_struct) {
  return Nlohmann::Factory::loadFromProtobufStruct(protobuf_struct);
}

std::vector<uint8_t> Factory::jsonToMsgpack(const std::string& json) {
  return Nlohmann::Factory::jsonToMsgpack(json);
}

} // namespace Json
} // namespace Envoy
