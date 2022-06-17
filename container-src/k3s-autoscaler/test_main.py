import unittest

import utils


class TestStringMethods(unittest.TestCase):

    def test_parse_memspec_to_bytes(self):
        assert utils.parse_memspec_to_bytes('8MiB') == 8 * 1024 * 1024
        assert utils.parse_memspec_to_bytes('8Mi') == 8 * 1024 * 1024
        assert utils.parse_memspec_to_bytes('8MB') == 8 * 1000 * 1000
        assert utils.parse_memspec_to_bytes('1024M') == 1024 * 1000 * 1000
        assert utils.parse_memspec_to_bytes('8k') == 8 * 1000
        assert utils.parse_memspec_to_bytes('8K') == 8 * 1000
        assert utils.parse_memspec_to_bytes('8kB') == 8 * 1000
        assert utils.parse_memspec_to_bytes('8KiB') == 8 * 1024
        assert utils.parse_memspec_to_bytes('64738 ') == 64738

        try:
            utils.parse_memspec_to_bytes('8Kib')
            assert False
        except ValueError:
            pass

        prefixes = ['k', 'M', 'G', 'T']
        postfixes = ['iB', 'i', 'B', '']

        for postfix in postfixes:
            base = utils.UNIT_FACTORS['K' + postfix]
            x = base
            for prefix in prefixes:
                if postfix in ('iB', 'i'):
                    prefix = prefix.upper()
                assert utils.parse_memspec_to_bytes('1' + prefix + postfix) == x
                x *= base


if __name__ == '__main__':
    unittest.main()
