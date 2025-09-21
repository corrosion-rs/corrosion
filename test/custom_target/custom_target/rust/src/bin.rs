use rust_lib::calculate_42;

fn main() {
    let answer = unsafe { calculate_42() } ;
    println!("The answer is {answer}");
}
