"""
GymGeek: PyTorch (.pth) → TFLite (.tflite) model conversion script.

Usage:
    python tools/convert_model.py \
        --pth path/to/model.pth \
        --labels path/to/labels.txt \
        --arch mobilenet_v2 \
        --num_classes 30 \
        --output assets/model.tflite

Supported --arch values:
    mobilenet_v2 (default), mobilenet_v3_small, mobilenet_v3_large,
    efficientnet_b0, resnet18, resnet50

Requirements:
    pip install torch torchvision onnx onnxruntime tensorflow
"""

import argparse
import os
import sys
import tempfile

import torch
import torch.nn as nn
import torchvision.models as models

# ── Argument parsing ─────────────────────────────────────────────────────────

def parse_args():
    parser = argparse.ArgumentParser(description="Convert .pth to .tflite for GymGeek")
    parser.add_argument("--pth", required=True, help="Path to the .pth model file")
    parser.add_argument("--output", default="assets/model.tflite", help="Output .tflite path")
    parser.add_argument("--labels", default=None, help="Path to labels.txt (one class per line)")
    parser.add_argument("--arch", default="mobilenet_v2",
                        choices=["mobilenet_v2", "mobilenet_v3_small", "mobilenet_v3_large",
                                 "efficientnet_b0", "resnet18", "resnet50"],
                        help="Model architecture used during training")
    parser.add_argument("--num_classes", type=int, default=None,
                        help="Number of output classes (inferred from labels.txt if provided)")
    parser.add_argument("--input_size", type=int, default=224,
                        help="Model input image size (default: 224)")
    return parser.parse_args()

# ── Architecture builder ──────────────────────────────────────────────────────

def build_model(arch: str, num_classes: int) -> nn.Module:
    if arch == "mobilenet_v2":
        m = models.mobilenet_v2(weights=None)
        m.classifier[1] = nn.Linear(m.classifier[1].in_features, num_classes)
    elif arch == "mobilenet_v3_small":
        m = models.mobilenet_v3_small(weights=None)
        m.classifier[3] = nn.Linear(m.classifier[3].in_features, num_classes)
    elif arch == "mobilenet_v3_large":
        m = models.mobilenet_v3_large(weights=None)
        m.classifier[3] = nn.Linear(m.classifier[3].in_features, num_classes)
    elif arch == "efficientnet_b0":
        m = models.efficientnet_b0(weights=None)
        m.classifier[1] = nn.Linear(m.classifier[1].in_features, num_classes)
    elif arch == "resnet18":
        m = models.resnet18(weights=None)
        m.fc = nn.Linear(m.fc.in_features, num_classes)
    elif arch == "resnet50":
        m = models.resnet50(weights=None)
        m.fc = nn.Linear(m.fc.in_features, num_classes)
    else:
        raise ValueError(f"Unknown architecture: {arch}")
    return m

# ── Load weights ──────────────────────────────────────────────────────────────

def load_weights(model: nn.Module, pth_path: str) -> nn.Module:
    state = torch.load(pth_path, map_location="cpu")

    # Handle common checkpoint formats
    if isinstance(state, dict):
        if "model_state_dict" in state:
            state = state["model_state_dict"]
        elif "state_dict" in state:
            state = state["state_dict"]
        # Strip "module." prefix from DataParallel training
        state = {k.replace("module.", ""): v for k, v in state.items()}

    model.load_state_dict(state)
    model.eval()
    print(f"Loaded weights from {pth_path}")
    return model

# ── PyTorch → ONNX ───────────────────────────────────────────────────────────

def export_onnx(model: nn.Module, onnx_path: str, input_size: int):
    dummy = torch.randn(1, 3, input_size, input_size)
    torch.onnx.export(
        model,
        dummy,
        onnx_path,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={"input": {0: "batch_size"}, "output": {0: "batch_size"}},
        opset_version=11,
        do_constant_folding=True,
    )
    print(f"Exported ONNX model to {onnx_path}")

    # Validate the ONNX model
    import onnx
    model_onnx = onnx.load(onnx_path)
    onnx.checker.check_model(model_onnx)
    print("ONNX model validated successfully")

# ── ONNX → TFLite ─────────────────────────────────────────────────────────────

def convert_tflite(onnx_path: str, tflite_path: str, input_size: int):
    try:
        import onnx_tf
        from onnx_tf.backend import prepare
    except ImportError:
        print("onnx-tf not found. Trying onnx2tf...")
        return convert_tflite_onnx2tf(onnx_path, tflite_path, input_size)

    import tensorflow as tf

    # ONNX → TF SavedModel
    with tempfile.TemporaryDirectory() as tmpdir:
        saved_model_dir = os.path.join(tmpdir, "saved_model")
        import onnx
        onnx_model = onnx.load(onnx_path)
        tf_rep = prepare(onnx_model)
        tf_rep.export_graph(saved_model_dir)
        print(f"Exported TF SavedModel to {saved_model_dir}")

        # TF SavedModel → TFLite
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,
            tf.lite.OpsSet.SELECT_TF_OPS,
        ]
        tflite_model = converter.convert()

    os.makedirs(os.path.dirname(tflite_path) or ".", exist_ok=True)
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)
    print(f"TFLite model saved to {tflite_path} ({len(tflite_model) / 1024:.1f} KB)")


def convert_tflite_onnx2tf(onnx_path: str, tflite_path: str, input_size: int):
    """Fallback using onnx2tf library (pip install onnx2tf)."""
    try:
        import onnx2tf
    except ImportError:
        print("\nERROR: Could not find onnx-tf or onnx2tf.")
        print("Install one of:\n  pip install onnx-tf\n  pip install onnx2tf")
        sys.exit(1)

    with tempfile.TemporaryDirectory() as tmpdir:
        onnx2tf.convert(
            input_onnx_file_path=onnx_path,
            output_folder_path=tmpdir,
            non_verbose=True,
        )
        # onnx2tf outputs saved_model + tflite in the folder
        tflite_candidates = [f for f in os.listdir(tmpdir) if f.endswith(".tflite")]
        if not tflite_candidates:
            print("ERROR: onnx2tf did not produce a .tflite file.")
            sys.exit(1)
        src = os.path.join(tmpdir, tflite_candidates[0])
        os.makedirs(os.path.dirname(tflite_path) or ".", exist_ok=True)
        import shutil
        shutil.copy(src, tflite_path)
    size_kb = os.path.getsize(tflite_path) / 1024
    print(f"TFLite model saved to {tflite_path} ({size_kb:.1f} KB)")

# ── Labels file ───────────────────────────────────────────────────────────────

def resolve_num_classes(labels_path, num_classes_arg):
    if labels_path:
        with open(labels_path) as f:
            labels = [l.strip() for l in f if l.strip()]
        n = len(labels)
        if num_classes_arg and num_classes_arg != n:
            print(f"WARNING: --num_classes {num_classes_arg} conflicts with "
                  f"{n} labels in {labels_path}. Using {n}.")
        return n, labels
    if num_classes_arg:
        return num_classes_arg, None
    # Default: Roboflow GymBro dataset v2 (rizzlabzz/gymbro) — 23 classes
    default_labels = [
        "abdominal-machine",
        "arm-curl",
        "arm-extension",
        "back-extension",
        "back-row-machine",
        "bench-press",
        "cable-lat-pulldown",
        "chest-fly",
        "chest-press",
        "dip-chin-assist",
        "hip-abduction-adduction",
        "incline-bench",
        "lat-pulldown",
        "leg-extension",
        "leg-press",
        "lying-down-leg-curl",
        "overhead-shoulder-press",
        "pulley-machine",
        "seated-cable-row",
        "seated-leg-curl",
        "smith-machine",
        "squat-rack",
        "torso-rotation-machine",
    ]
    print(f"No labels file provided. Using {len(default_labels)} Roboflow GymBro classes.")
    return len(default_labels), default_labels


def write_labels(labels, output_tflite_path):
    labels_path = output_tflite_path.replace(".tflite", "_labels.txt")
    with open(labels_path, "w") as f:
        for label in labels:
            f.write(label + "\n")
    print(f"Labels written to {labels_path}")
    print(f"\nCopy both files to Flutter assets/:")
    print(f"  {output_tflite_path}  →  assets/model.tflite")
    print(f"  {labels_path}         →  assets/labels.txt")
    print("\nThen uncomment model assets in pubspec.yaml:")
    print("  - assets/model.tflite")
    print("  - assets/labels.txt")

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    args = parse_args()

    num_classes, labels = resolve_num_classes(args.labels, args.num_classes)
    print(f"Architecture : {args.arch}")
    print(f"Num classes  : {num_classes}")
    print(f"Input size   : {args.input_size}x{args.input_size}")

    model = build_model(args.arch, num_classes)
    model = load_weights(model, args.pth)

    with tempfile.NamedTemporaryFile(suffix=".onnx", delete=False) as tmp:
        onnx_path = tmp.name

    try:
        export_onnx(model, onnx_path, args.input_size)
        convert_tflite(onnx_path, args.output, args.input_size)
    finally:
        if os.path.exists(onnx_path):
            os.remove(onnx_path)

    if labels:
        write_labels(labels, args.output)

    print("\nDone! Integration steps:")
    print("1. Move model.tflite and labels.txt into gymgeek/assets/")
    print("2. Uncomment 'assets/model.tflite' and 'assets/labels.txt' in pubspec.yaml")
    print("3. In tflite_service.dart: set _demoMode = false")


if __name__ == "__main__":
    main()
