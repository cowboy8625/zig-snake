const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 800;
const CELL_SIZE = 25;

fn normalize(pos: ray.Vector2) struct { x: c_int, y: c_int } {
    const x = @as(c_int, @intFromFloat(@trunc(pos.x))) * CELL_SIZE;
    const y = @as(c_int, @intFromFloat(@trunc(pos.y))) * CELL_SIZE;
    return .{ .x = x, .y = y };
}

const Button = struct {
    const Self = @This();

    text: [:0]const u8,

    position: ray.Vector2,
    callback: *const fn () void,

    color_bg: ray.Color = ray.RED,
    color_text: ray.Color = ray.WHITE,
    is_hovered: bool = false,
    font_size: f32 = 40,
    offset: f32 = 40,

    fn get_rect(self: *Self) ray.Rectangle {
        const text_size = ray.MeasureTextEx(ray.GetFontDefault(), self.text, self.font_size, 0);
        const width = text_size.x + self.offset;
        const height = text_size.y + self.offset;
        const x = self.position.x - width / 2;
        const y = self.position.y - height / 2;
        return ray.Rectangle{ .x = x, .y = y, .width = width, .height = height };
    }

    fn update(self: *Self) void {
        const bounding_box = self.get_rect();
        self.is_hovered = false;
        if (ray.CheckCollisionPointRec(ray.GetMousePosition(), bounding_box)) {
            self.is_hovered = true;
            if (ray.IsMouseButtonPressed(ray.MOUSE_LEFT_BUTTON)) {
                self.callback();
            }
        }
    }

    fn draw(self: *Self) void {
        const rect = self.get_rect();
        const color_bg = if (!self.is_hovered) self.color_bg else ray.BLUE;
        ray.DrawRectangleV(ray.Vector2{ .x = rect.x, .y = rect.y }, ray.Vector2{ .x = rect.width, .y = rect.height }, color_bg);
        const x_text = (self.offset / 4) + rect.x;
        const y_text = (self.offset / 2) + rect.y;
        ray.DrawText(self.text, @as(c_int, @intFromFloat(x_text)), @as(c_int, @intFromFloat(y_text)), @as(c_int, @intFromFloat(self.font_size)), self.color_text);
    }
};

const Snake = struct {
    const Self = @This();

    head: ray.Vector2,
    allocator: std.mem.Allocator,

    direction: Direction = Direction.Right,
    speed: f32 = 10.0,
    body: std.ArrayList(ray.Vector2),
    length: usize = 5,
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .head = ray.Vector2{ .x = 25, .y = 25 },
            .allocator = allocator,
            .body = std.ArrayList(ray.Vector2).init(allocator),
        };
    }

    pub fn reset(self: *Self) void {
        self.head = ray.Vector2{ .x = 25, .y = 25 };
        self.direction = Direction.Right;
        self.length = 5;
        self.speed = 10.0;
        self.body.clearRetainingCapacity();
    }

    pub fn deinit(self: *Self) void {
        self.body.deinit();
    }

    pub fn update(self: *Self) !void {
        if (self.body.items.len >= self.length) {
            _ = self.body.pop();
        }

        if (self.body.items.len == 0 and self.length > 0) {
            try self.body.insert(0, self.head);
        }

        if (self.body.items.len > 0) {
            const section = normalize(self.body.items[0]);
            const x1 = section.x;
            const y1 = section.y;
            const current = normalize(self.head);
            const x2 = current.x;
            const y2 = current.y;
            if (x1 != x2 or y1 != y2) {
                try self.body.insert(0, self.head);
            }
        }

        if (ray.IsKeyDown(ray.KEY_D)) {
            self.direction = Direction.Right;
        } else if (ray.IsKeyDown(ray.KEY_A)) {
            self.direction = Direction.Left;
        } else if (ray.IsKeyDown(ray.KEY_S)) {
            self.direction = Direction.Down;
        } else if (ray.IsKeyDown(ray.KEY_W)) {
            self.direction = Direction.Up;
        }

        const delta = self.speed * ray.GetFrameTime();
        switch (self.direction) {
            Direction.Up => {
                self.head.y -= delta;
                if (self.head.y < 0) {
                    self.head.y = SCREEN_HEIGHT / CELL_SIZE;
                }
            },
            Direction.Down => {
                self.head.y += delta;
                if (self.head.y >= SCREEN_HEIGHT / CELL_SIZE) {
                    self.head.y = 0;
                }
            },
            Direction.Left => {
                self.head.x -= delta;
                if (self.head.x < 0) {
                    self.head.x = SCREEN_WIDTH / CELL_SIZE;
                }
            },
            Direction.Right => {
                self.head.x += delta;
                if (self.head.x >= SCREEN_WIDTH / CELL_SIZE) {
                    self.head.x = 0;
                }
            },
        }
    }

    pub fn move_up(self: Self) void {
        self.head.move_up();
    }

    pub fn move_down(self: Self) void {
        self.head.move_down();
    }

    pub fn move_left(self: Self) void {
        self.head.move_left();
    }

    pub fn move_right(self: Self) void {
        self.head.move_right();
    }

    pub fn draw(self: Self) void {
        for (0.., self.body.items) |i, section| {
            const color = if (i == 0) ray.RED else ray.GREEN;
            const x = @as(c_int, @intFromFloat(section.x));
            const y = @as(c_int, @intFromFloat(section.y));
            ray.DrawRectangle(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE, color);
        }
    }
};

const Direction = enum {
    Up,
    Down,
    Left,
    Right,
};

const Food = struct {
    const Self = @This();

    pos: ray.Vector2,

    pub fn draw(self: *Self) void {
        const x = @as(c_int, @intFromFloat(@trunc(self.pos.x)));
        const y = @as(c_int, @intFromFloat(@trunc(self.pos.y)));
        ray.DrawRectangle(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE, ray.GREEN);
    }
};

var reset = false;

fn foo() void {
    reset = true;
}

pub fn main() !void {
    var is_alive = true;
    var snake = Snake.init(std.heap.page_allocator);
    defer snake.deinit();

    var food = Food{ .pos = ray.Vector2{ .x = 10, .y = 1 } };
    var restart_button = Button{ .callback = foo, .position = ray.Vector2{ .x = SCREEN_WIDTH / 2, .y = (SCREEN_HEIGHT / 3) * 2 }, .text = "Restart" };

    ray.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Snake");
    defer ray.CloseWindow(); // Close window and OpenGL context

    ray.SetTargetFPS(60); // Set our game to run at 60 frames-per-second

    while (!ray.WindowShouldClose()) // Detect window close button or ESC key
    {
        // Update
        //----------------------------------------------------------------------------------
        //----------------------------------------------------------------------------------

        if (reset) {
            snake.reset();
            is_alive = true;
            reset = false;
        }
        restart_button.update();

        if (is_alive) {
            try snake.update();
        }

        const pos = normalize(snake.head);

        for (snake.body.items[1..]) |section| {
            const sec = normalize(section);
            if (pos.x == sec.x and pos.y == sec.y) {
                is_alive = false;
            }
        }

        const food_pos = normalize(food.pos);

        if (pos.x == food_pos.x and pos.y == food_pos.y) {
            snake.length += 1;
            snake.speed += 0.1;
            try snake.body.insert(0, food.pos);
            food.pos = ray.Vector2{ .x = @as(f32, @floatFromInt(ray.GetRandomValue(0, SCREEN_WIDTH / CELL_SIZE))), .y = @as(f32, @floatFromInt(ray.GetRandomValue(0, SCREEN_HEIGHT / CELL_SIZE))) };
        }

        // Draw
        //----------------------------------------------------------------------------------
        //----------------------------------------------------------------------------------
        ray.BeginDrawing();
        defer ray.EndDrawing();

        if (is_alive) {
            snake.draw();

            food.draw();
        }

        if (!is_alive) {
            const font_size = 40;
            const text_size = ray.MeasureTextEx(ray.GetFontDefault(), "Game Over", font_size, 0);
            const x = @as(c_int, @intFromFloat((SCREEN_WIDTH - text_size.x) / 2));
            const y = @as(c_int, @intFromFloat((SCREEN_HEIGHT - text_size.y) / 2));
            ray.DrawText("Game Over", x, y, font_size, ray.BLACK);
            restart_button.draw();
        }

        ray.ClearBackground(ray.RAYWHITE);
        //----------------------------------------------------------------------------------
    }
}
