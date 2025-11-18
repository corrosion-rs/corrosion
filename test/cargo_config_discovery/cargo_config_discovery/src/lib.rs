use bitflags::bitflags;

bitflags! {
    pub struct TestFlags: u32 {
        const VALUE = 0b00000001;
    }
}
