const std = @import("std");
const testing = std.testing;

/// Creates a `Distinct` type.
/// You must pass either `opaque {}` or `struct {}` as `empty_opaque` argument.
/// You need to save the returned type to use it later:
/// ```zig
/// const Force = Distinct(f32, opaque {});
/// const Mass = Distinct(f32, opaque {});
/// fn acceleration(mass: Mass, force: Force) {...}
/// ```
pub fn Distinct(comptime T: type, comptime empty_opaque: type) type {
    return struct {
        t: T,
        const _ = empty_opaque;
    };
}

/// Merges structs into a new one. Resulting struct contains all the fields of source structs.
pub fn MergeStructs(comptime types: []const type) type {
    var fields_count: usize = 0;
    for (types) |t| {
        fields_count += std.meta.fields(t).len;
    }
    var fields = std.BoundedArray(std.builtin.Type.StructField, fields_count){};
    for (types) |t| {
        fields.appendSlice(std.meta.fields(t)) catch unreachable;
    }
    return @Type(std.builtin.Type{
        .Struct = .{
            .layout = .auto,
            .fields = fields.slice(),
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

/// Creates a struct consisting of multiple structs mixed in:
/// ```zig
/// struct {
///   pub usingnamespace types[0];
///   pub usingnamespace types[1];
///   ...
///   pub usingnamespace types[types.len - 1];
/// };
/// ```
pub fn ChainMixin(comptime types: []const type) type {
    if (types.len == 0) return struct {};
    return struct {
        pub usingnamespace types[0];
        pub usingnamespace ChainMixin(types[1..]);
    };
}

test "Distinct" {
    const A = Distinct(u32, opaque {});
    const B = Distinct(u32, opaque {});
    const C = B;

    try testing.expect(A != B);
    try testing.expect(B == C);
}

test "ChainMixin" {
    const Namespace = struct {
        fn MixinA(comptime T: type) type {
            return struct {
                const Self = T;
                fn add(lhs: T, rhs: T) i32 {
                    return lhs.x + rhs.x;
                }
            };
        }

        fn MixinB(comptime T: type) type {
            return struct {
                const Self = T;
                fn sub(lhs: T, rhs: T) i32 {
                    return lhs.x - rhs.x;
                }
            };
        }
    };

    const A = struct {
        usingnamespace ChainMixin(&.{
            Namespace.MixinA(@This()),
            Namespace.MixinB(@This()),
        });
        x: i32 = 0,
    };

    const lhs = A{ .x = 100 };
    const rhs = A{ .x = 50 };

    try testing.expectEqual(@as(i32, 150), lhs.add(rhs));
    try testing.expectEqual(@as(i32, 50), lhs.sub(rhs));
}

test "MergeStructs" {
    const A = struct {
        a: i32,
        b: f32,
    };

    const B = struct {
        c: [4]bool,
        d: void,
    };

    const C = MergeStructs(&.{ A, B });
    const Expected = struct {
        a: i32,
        b: f32,
        c: [4]bool,
        d: void,
    };

    // That's a hack to compare two structs.
    try testing.expectEqualStrings(
        std.fmt.comptimePrint("{any}", .{std.meta.fields(Expected)}),
        std.fmt.comptimePrint("{any}", .{std.meta.fields(C)}),
    );
}
