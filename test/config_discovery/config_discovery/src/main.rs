use bitflags::bitflags;

bitflags! {
    struct TestFlags: u32 {
        const VALUE = 0b00000001;
    }
}

fn main() {
    let flags = TestFlags::VALUE;
    println!("Flag value: {}", flags.bits());
}
