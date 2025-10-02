delay: f32,
rate: f32,

held: f32 = 0,
state: enum {
    initial,
    repeat,
} = .initial,

pub fn trigger(self: *@This(), held: bool, dt: f32) bool {
    if (!held) {
        self.held = 0;
        self.state = .initial;
        return false;
    }

    defer self.held += dt;
    switch (self.state) {
        .initial => {
            if (self.held + dt > self.delay) {
                self.state = .repeat;
                self.held = self.rate;
            }
            if (self.held == 0)
                return true;
        },
        .repeat => {
            if (self.held >= self.rate) {
                self.held -= self.rate;
                return true;
            }
        },
    }
    return false;
}
