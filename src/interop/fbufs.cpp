#include <cstddef>
#include <cstdint>
#include <cstring>

#include "hydration_message_generated.h"
#include "user_auth_generated.h"
#include "user_signup_generated.h"

namespace {

enum Status {
  STATUS_OK,
  STATUS_BUFFER_TOO_SMALL,
  STATUS_INVALID_BUFFER,
  STATUS_ENCODE_FAILED,
};

struct UserSignupView {
  const char *username;
  std::size_t username_size;
  const char *password;
  std::size_t password_size;
};

struct HydrationMessageView {
  const char *name;
  std::size_t name_size;
};

} // namespace

extern "C" int
blackkeys_user_auth_encode(char *output, std::size_t output_capacity,
                           const char *username, std::size_t username_size,
                           const char *password, std::size_t password_size,
                           std::size_t *output_size) {
  if (output == nullptr || username == nullptr || password == nullptr ||
      output_size == nullptr)
    return STATUS_ENCODE_FAILED;

  try {
    flatbuffers::FlatBufferBuilder builder;
    auto username_offset = builder.CreateString(username, username_size);
    auto password_offset = builder.CreateString(password, password_size);
    auto message = blackkeys::schema::CreateUserAuth(builder, username_offset,
                                                     password_offset);
    blackkeys::schema::FinishUserAuthBuffer(builder, message);

    *output_size = builder.GetSize();
    if (*output_size > output_capacity)
      return STATUS_BUFFER_TOO_SMALL;
    std::memcpy(output, builder.GetBufferPointer(), *output_size);
    return STATUS_OK;
  } catch (...) {
    return STATUS_ENCODE_FAILED;
  }
}

extern "C" int blackkeys_user_signup_has_identifier(const char *buffer,
                                                    std::size_t size) {
  constexpr std::size_t identifier_end = sizeof(flatbuffers::uoffset_t) + 4;
  return buffer != nullptr && size >= identifier_end &&
         blackkeys::schema::UserSignupBufferHasIdentifier(buffer);
}

extern "C" int blackkeys_user_signup_decode(const char *buffer,
                                            std::size_t size,
                                            UserSignupView *view) {
  if (buffer == nullptr || view == nullptr)
    return STATUS_INVALID_BUFFER;

  flatbuffers::Verifier verifier(reinterpret_cast<const std::uint8_t *>(buffer),
                                 size);
  if (!blackkeys::schema::VerifyUserSignupBuffer(verifier))
    return STATUS_INVALID_BUFFER;

  const auto *message = blackkeys::schema::GetUserSignup(buffer);
  view->username = message->username()->c_str();
  view->username_size = message->username()->size();
  view->password = message->password()->c_str();
  view->password_size = message->password()->size();
  return STATUS_OK;
}

extern "C" int blackkeys_hydration_message_has_identifier(const char *buffer,
                                                           std::size_t size) {
  constexpr std::size_t identifier_end = sizeof(flatbuffers::uoffset_t) + 4;
  return buffer != nullptr && size >= identifier_end &&
         blackkeys::schema::HydrationMessageBufferHasIdentifier(buffer);
}

extern "C" int
blackkeys_hydration_message_decode(const char *buffer, std::size_t size,
                                    HydrationMessageView *view) {
  if (buffer == nullptr || view == nullptr)
    return STATUS_INVALID_BUFFER;

  flatbuffers::Verifier verifier(reinterpret_cast<const std::uint8_t *>(buffer),
                                 size);
  if (!blackkeys::schema::VerifyHydrationMessageBuffer(verifier))
    return STATUS_INVALID_BUFFER;

  const auto *message = blackkeys::schema::GetHydrationMessage(buffer);
  view->name = message->name()->c_str();
  view->name_size = message->name()->size();
  return STATUS_OK;
}
