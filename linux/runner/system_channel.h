#ifndef SYSTEM_CHANNEL_H_
#define SYSTEM_CHANNEL_H_

#include <flutter_linux/flutter_linux.h>

// Registers the "krdos/system" MethodChannel on the given plugin registry.
// Must be called once, after fl_register_plugins() in my_application.cc.
void system_channel_init(FlPluginRegistry* registry);

#endif  // SYSTEM_CHANNEL_H_
