pub fn main() void {
    const big: u16 = 1000;
    const smol: u8 = @intCast(big);
    _ = smol;
}
