/// writes the given data to a port
pub fn out(port: u16, data: anytype) void {
    switch (@TypeOf(data)) {
        u32 => asm volatile ("outl %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{eax}" (data),
        ),
        u16 => asm volatile ("outw %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{ax}" (data),
        ),
        u8 => asm volatile ("outb %[data], %[port]"
            :
            : [port] "{dx}" (port),
              [data] "{al}" (data),
        ),
        else => @compileError("invalid type"),
    }
}

/// reads data from a port and returns its value
pub fn in(port: u16, comptime T: type) T {
    return switch (T) {
        u32 => asm volatile ("inl %[port], %[result]"
            : [result] "={eax}" (-> T),
            : [port] "N{dx}" (port),
        ),
        u16 => asm volatile ("inw %[port], %[result]"
            : [result] "={ax}" (-> T),
            : [port] "N{dx}" (port),
        ),
        u8 => asm volatile ("inb %[port], %[result]"
            : [result] "={al}" (-> T),
            : [port] "N{dx}" (port),
        ),
        else => @compileError("invalid type"),
    };
}

pub fn Port(comptime T: type) type {
    return struct {
        addr: u16,
        const Self = @This();
        pub fn init(addr: u16) Self {
            return .{
                .addr = addr,
            };
        }
        pub fn read(self: *const Self) T {
            return in(self.addr, T);
        }

        pub fn write(self: *const Self, data: T) void {
            out(self.addr, data);
        }
    };
}
