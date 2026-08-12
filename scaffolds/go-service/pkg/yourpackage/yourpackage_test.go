package yourpackage

import "testing"

func TestNewGreeter(t *testing.T) {
    name := "World"
    g := NewGreeter(name)
    
    if g.Name != name {
        t.Errorf("Expected name %s, got %s", name, g.Name)
    }
}

func TestGreet(t *testing.T) {
    name := "World"
    g := NewGreeter(name)
    greeting := g.Greet()
    
    expected := "Hello, World!"
    if greeting != expected {
        t.Errorf("Expected greeting %s, got %s", expected, greeting)
    }
}
