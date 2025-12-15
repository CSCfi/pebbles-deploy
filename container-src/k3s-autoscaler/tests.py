import unittest
from types import SimpleNamespace

import utils
from image_puller import ImagePuller


# ---------- Helpers to build fake nodes & pods ----------
def make_node(name, images=None):
    images = images or []
    image_objs = [SimpleNamespace(names=nlist) for nlist in images]
    return SimpleNamespace(
        metadata=SimpleNamespace(name=name),
        status={'images': image_objs}
    )


def make_pod(name, phase, created, images):
    containers = [SimpleNamespace(image=i) for i in images]
    return SimpleNamespace(
        metadata=SimpleNamespace(name=name, creationTimestamp=created),
        status=SimpleNamespace(phase=phase),
        spec=SimpleNamespace(containers=containers)
    )


class TestImagePullerUnit(unittest.TestCase):

    def test_find_active_images_filters_running_and_orders_by_recency(self):
        pods = [
            make_pod("old-running", "Running", 1, ["repo/a:1", "repo/b:1"]),
            make_pod("new-running", "Running", 3, ["repo/b:1", "repo/c:1"]),
            make_pod("pending", "Pending", 2, ["repo/d:1"]),
            make_pod("succeeded", "Succeeded", 4, ["repo/e:1"]),
        ]
        res = ImagePuller._find_active_images(pods)
        # Expected: newest running first, de-dup by first occurrence
        self.assertEqual(res, ["repo/b:1", "repo/c:1", "repo/a:1"])

    def test_find_missing_basic(self):
        node_a = make_node("node-a", images=[["repo/a:2"]])
        nodes = [node_a]
        images = ["repo/a:1", "repo/a:2", "repo/b:1"]
        res = ImagePuller._find_missing_node_image_pairs(
            nodes, images, pull_history=set(), ignorelist=[]
        )
        self.assertEqual(res, [(node_a, "repo/a:1"), (node_a, "repo/b:1")])

    def test_find_missing_respects_ignorelist_prefix(self):
        node_a = make_node("node-a")
        nodes = [node_a]
        images = ["repo/a:1", "other/a:1"]
        res = ImagePuller._find_missing_node_image_pairs(
            nodes, images, pull_history=set(), ignorelist=["repo/"]
        )
        self.assertEqual(res, [(node_a, "other/a:1")])

    def test_find_missing_respects_pull_history(self):
        node_a = make_node("node-a")
        nodes = [node_a]
        images = ["repo/a:1"]
        pull_history = {"node-a:repo/a:1"}
        res = ImagePuller._find_missing_node_image_pairs(
            nodes, images, pull_history=pull_history, ignorelist=[]
        )
        self.assertEqual(res, [])


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
