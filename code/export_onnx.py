"""Build the deployed actor as ONNX (z[1x6] -> tau[1x2]) and check it against MATLAB.
tau = clip(W3 relu(W2 relu(W1 z + b1) + b2) + b3 + K z + kb, -sat, sat)."""
import json, sys, os
import numpy as np
import onnx
from onnx import helper, TensorProto, numpy_helper
from onnx.reference import ReferenceEvaluator
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tag = sys.argv[1] if len(sys.argv) > 1 else "res_32"
J = json.load(open(os.path.join(ROOT, "models", f"actor_{tag}.json")))
A = lambda x: np.atleast_2d(np.array(x, dtype=np.float64))
W = [A(w) for w in J["W"]]; b = [np.array(x, dtype=np.float64).reshape(-1) for x in J["b"]]
K = A(J["K"]); kb = np.array(J["kb"], dtype=np.float64).reshape(-1); sat = np.array(J["sat"], dtype=np.float64).reshape(-1)
inits, nodes = [], []
def const(name, arr):
    inits.append(numpy_helper.from_array(arr.astype(np.float32), name)); return name
x = "z"
for i in range(len(W)):
    y = f"h{i}"
    nodes.append(helper.make_node("Gemm", [x, const(f"W{i}", W[i]), const(f"b{i}", b[i])], [y], transB=1))
    if i < len(W) - 1:
        nodes.append(helper.make_node("Relu", [y], [y + "r"])); x = y + "r"
    else:
        x = y
nodes.append(helper.make_node("Gemm", ["z", const("K", K), const("kb", kb)], ["lin"], transB=1))
nodes.append(helper.make_node("Add", [x, "lin"], ["pre"]))
nodes.append(helper.make_node("Max", ["pre", const("negsat", -sat)], ["lo"]))
nodes.append(helper.make_node("Min", ["lo", const("sat", sat)], ["tau"]))
g = helper.make_graph(nodes, f"uwoc_actor_{tag}",
                      [helper.make_tensor_value_info("z", TensorProto.FLOAT, [None, 6])],
                      [helper.make_tensor_value_info("tau", TensorProto.FLOAT, [None, 2])], inits)
m = helper.make_model(g, producer_name="uwoc-assurance", opset_imports=[helper.make_opsetid("", 13)])
onnx.checker.check_model(m)
out = os.path.join(ROOT, "models", f"actor_{tag}.onnx")
onnx.save(m, out)
Z = A(J["Z"]).T.astype(np.float32); Yref = A(J["Y"]).T
Y = ReferenceEvaluator(m).run(None, {"z": Z})[0]
err = np.abs(Y - Yref).max()
print(f"saved {out}; max |onnx - matlab| over {len(Z)} points = {err:.3e} (float32)")
json.dump({"tag": tag, "max_abs_err": float(err), "n_points": int(len(Z)), "opset": 13},
          open(os.path.join(ROOT, "models", f"onnx_check_{tag}.json"), "w"))
