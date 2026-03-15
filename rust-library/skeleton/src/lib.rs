pub fn hello(name: &str) -> String {
    format!("Hello from ${{ values.name }}, {name}!")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hello() {
        assert_eq!(hello("world"), "Hello from ${{ values.name }}, world!");
    }
}
