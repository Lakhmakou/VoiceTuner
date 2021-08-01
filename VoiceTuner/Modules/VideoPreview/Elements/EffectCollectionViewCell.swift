//
//  EffectCollectionViewCell.swift
//  VoiceTuner
//
//  Created by Max on 31.07.21.
//

import UIKit

class EffectCollectionViewCell: UICollectionViewCell {

  @IBOutlet private weak var effectImageView: UIImageView!
  
  override func awakeFromNib() {
        super.awakeFromNib()
    layer.cornerRadius = bounds.width / 2
    effectImageView.layer.cornerRadius = bounds.width / 2
    }

  func configure(with image: UIImage) {
    effectImageView.image = image
  }
}
