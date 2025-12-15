import jinja2

UNIT_FACTORS = dict(
    KiB=1024,
    MiB=1024 * 1024,
    GiB=1024 * 1024 * 1024,
    TiB=1024 * 1024 * 1024 * 1024,
    Ki=1024,
    Mi=1024 * 1024,
    Gi=1024 * 1024 * 1024,
    Ti=1024 * 1024 * 1024 * 1024,
    kB=1000,
    KB=1000,
    MB=1000 * 1000,
    GB=1000 * 1000 * 1000,
    TB=1000 * 1000 * 1000 * 1000,
    k=1000,
    K=1000,
    M=1000 * 1000,
    G=1000 * 1000 * 1000,
    T=1000 * 1000 * 1000 * 1000,
)


def parse_memspec_to_bytes(memspec):
    # first try last 3 characters (8MiB)
    factor = UNIT_FACTORS.get(memspec[-3:])
    if factor:
        return factor * int(memspec[:-3])

    # then last 2 characters (8Gi, 8MB)
    factor = UNIT_FACTORS.get(memspec[-2:])
    if factor:
        return factor * int(memspec[:-2])

    # then last character
    factor = UNIT_FACTORS.get(memspec[-1:])
    if factor:
        return factor * int(memspec[:-1])
    # no factor found (8192), try just converting the value
    return int(memspec)


def format_with_jinja2(template_str, values):
    env = jinja2.Environment()
    env.filters['bool'] = bool
    template = env.from_string(template_str)
    return template.render(values)


def parse_jinja2(filename, values):
    with open(filename, 'r') as f:
        template = f.read()
        return format_with_jinja2(template, values)

def read_first_line_or_none(path):
    try:
        with open(path, 'r') as f:
            return f.readline().rstrip('\n')
    except FileNotFoundError:
        return None
