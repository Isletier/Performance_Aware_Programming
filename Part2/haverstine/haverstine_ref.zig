const asin = @import("std").math.asin;

fn rad_from_deg(deg: f64) f64 {
    const result: f64 = 0.01745329251994329577 * deg;
    return result;
}

fn square(x: f64) f64 {
    return x * x;
}

pub fn haverstine_ref(x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) f64 {
    const lat1: f64 = y1;
    const lat2: f64 = y2;
    const lon1: f64 = x1;
    const lon2: f64 = x2;

    const dLat = rad_from_deg(lat2 - lat1);
    const dLon = rad_from_deg(lon2 - lon1);
    const lat_1 = rad_from_deg(lat1);
    const lat_2 = rad_from_deg(lat2);

    const a = square(@sin(dLat/2.0)) + @cos(lat_1)*@cos(lat_2)*square(@sin(dLon/2));
    const c = 2.0*asin(@sqrt(a));

    const Result: f64 = radius * c;
    
    return Result;

}
