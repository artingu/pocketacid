// Copyright (C) 2025  Philip Linde
//
// This file is part of corrode.
//
// corrode is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// corrode is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with corrode.  If not, see <https://www.gnu.org/licenses/>.

pub const Queued = packed struct {
    row: u8 = 0,
    nothing: bool = true,
    _: u7 = 0,
};
