import 'package:flutter/material.dart';

const _dotPositions = {
  1: [4],
  2: [0, 8],
  3: [0, 4, 8],
  4: [0, 2, 6, 8],
  5: [0, 2, 4, 6, 8],
  6: [0, 2, 3, 5, 6, 8],
};

class DiceCellWidget extends StatelessWidget {
  final int value;
  final bool isSelected;
  final double size;
  final VoidCallback? onTap;

  const DiceCellWidget({
    super.key,
    required this.value,
    this.isSelected = false,
    this.size = 44,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.2),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFfacc15)
                : const Color(0xFFcbd5e1),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            if (isSelected)
              BoxShadow(
                color: const Color(0xFFfacc15).withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.1),
          child: _buildDotGrid(),
        ),
      ),
    );
  }

  Widget _buildDotGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        final hasDot = _dotPositions[value]?.contains(index) ?? false;
        if (!hasDot) return const SizedBox();
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [const Color(0xFF444444), const Color(0xFF000000)],
            ),
          ),
        );
      },
    );
  }
}

class DiceCellRow extends StatelessWidget {
  final List<int> diceValues;
  final int? selectedIndex;
  final Function(int)? onDieTap;
  final double cellSize;

  const DiceCellRow({
    super.key,
    required this.diceValues,
    this.selectedIndex,
    this.onDieTap,
    this.cellSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    if (diceValues.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          2,
          (i) => Padding(
            padding: EdgeInsets.only(right: i < 1 ? 8 : 0),
            child: _EmptyDiceCell(size: cellSize),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(diceValues.length, (index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index < diceValues.length - 1 ? 8 : 0,
          ),
          child: DiceCellWidget(
            value: diceValues[index],
            isSelected: selectedIndex == index,
            size: cellSize,
            onTap: onDieTap != null ? () => onDieTap!(index) : null,
          ),
        );
      }),
    );
  }
}

class _EmptyDiceCell extends StatelessWidget {
  final double size;

  const _EmptyDiceCell({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFf1f5f9),
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: const Color(0xFFcbd5e1), width: 2),
      ),
      child: Center(
        child: Icon(
          Icons.casino_outlined,
          color: const Color(0xFFcbd5e1),
          size: size * 0.5,
        ),
      ),
    );
  }
}
