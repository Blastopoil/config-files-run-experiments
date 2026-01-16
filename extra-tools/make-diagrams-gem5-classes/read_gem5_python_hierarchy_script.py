import re
import sys
from graphviz import Digraph

def parse_classes(filename):
    """
    Reads the file and returns a dictionary:
    {class: parent}
    """
    class_pattern = re.compile(r"class\s+(\w+)(?:\((\w+)\))?:")
    classes = {}

    with open(filename, "r") as f:
        for line in f:
            match = class_pattern.match(line.strip())
            if match:
                child, parent = match.groups()
                if parent is None:
                    parent = "object"
                classes[child] = parent
    return classes


def build_graph(classes, output="hierarchy"):
    dot = Digraph(comment="Class Hierarchy", format="png")
    for child, parent in classes.items():
        dot.node(child, child)
        dot.node(parent, parent)
        dot.edge(parent, child)
    dot.render(output, view=True)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 read_gem5_python_hierarchy_script.py BranchPredictor.py")
        sys.exit(1)

    filename = sys.argv[1]
    classes = parse_classes(filename)
    build_graph(classes)

